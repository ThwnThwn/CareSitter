BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nutrition_catalog_importer') THEN
  CREATE ROLE nutrition_catalog_importer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nutrition_catalog_reviewer') THEN
  CREATE ROLE nutrition_catalog_reviewer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nutrition_catalog_publisher') THEN
  CREATE ROLE nutrition_catalog_publisher NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
 END IF;
END $$;

CREATE TABLE nutrition.catalog_packages (
 id uuid PRIMARY KEY,
 package_key text NOT NULL CHECK(package_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
 version integer NOT NULL CHECK(version > 0),
 status text NOT NULL CHECK(status IN ('draft','reviewed','published','retired')),
 payload jsonb NOT NULL,
 payload_digest text NOT NULL CHECK(payload_digest ~ '^[a-f0-9]{64}$'),
 imported_by text NOT NULL CHECK(length(trim(imported_by)) > 0),
 imported_at timestamptz NOT NULL DEFAULT now(),
 reviewed_by text,
 reviewed_at timestamptz,
 published_by text,
 published_at timestamptz,
 retired_by text,
 retired_at timestamptz,
 retire_reason text,
 UNIQUE(package_key,version),
 CHECK(status = 'draft' OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)),
 CHECK(status NOT IN ('published','retired') OR (published_by IS NOT NULL AND published_at IS NOT NULL)),
 CHECK(status <> 'retired' OR (retired_by IS NOT NULL AND retired_at IS NOT NULL AND length(trim(retire_reason)) > 0))
);
CREATE UNIQUE INDEX ux_nutrition_catalog_package_published
 ON nutrition.catalog_packages(package_key) WHERE status='published';

CREATE TABLE nutrition.catalog_package_entries (
 package_id uuid NOT NULL REFERENCES nutrition.catalog_packages(id),
 content_kind text NOT NULL CHECK(content_kind IN ('recipe','rule')),
 version_id uuid NOT NULL,
 logical_id uuid NOT NULL,
 version integer NOT NULL CHECK(version > 0),
 PRIMARY KEY(package_id,content_kind,version_id)
);
CREATE UNIQUE INDEX ux_nutrition_catalog_active_entry
 ON nutrition.catalog_package_entries(content_kind,version_id);

CREATE TABLE nutrition.catalog_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 package_id uuid NOT NULL REFERENCES nutrition.catalog_packages(id),
 package_key text NOT NULL,
 package_version integer NOT NULL,
 action text NOT NULL CHECK(action IN ('imported','reviewed','published','retired','superseded')),
 actor text NOT NULL CHECK(length(trim(actor)) > 0),
 payload_digest text NOT NULL,
 metadata jsonb NOT NULL DEFAULT '{}',
 occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE FUNCTION nutrition.guard_recipe_catalog_content() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' AND OLD.status IN ('published','retired') THEN RAISE EXCEPTION 'Published catalog content is immutable' USING ERRCODE='55000'; END IF;
 IF TG_OP='UPDATE' AND OLD.status IN ('published','retired') AND NOT (
    OLD.status='published' AND NEW.status='retired' AND NEW.id=OLD.id AND NEW.recipe_id=OLD.recipe_id
    AND NEW.version=OLD.version AND NEW.payload=OLD.payload AND NEW.reviewed_by IS NOT DISTINCT FROM OLD.reviewed_by
    AND NEW.reviewed_at IS NOT DISTINCT FROM OLD.reviewed_at AND NEW.published_at IS NOT DISTINCT FROM OLD.published_at) THEN
  RAISE EXCEPTION 'Published catalog content is immutable' USING ERRCODE='55000';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END $$;
CREATE FUNCTION nutrition.guard_rule_catalog_content() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' AND OLD.status IN ('published','retired') THEN RAISE EXCEPTION 'Published catalog content is immutable' USING ERRCODE='55000'; END IF;
 IF TG_OP='UPDATE' AND OLD.status IN ('published','retired') AND NOT (
    OLD.status='published' AND NEW.status='retired' AND NEW.id=OLD.id AND NEW.rule_id=OLD.rule_id
    AND NEW.version=OLD.version AND NEW.payload=OLD.payload AND NEW.reviewed_by IS NOT DISTINCT FROM OLD.reviewed_by
    AND NEW.reviewed_at IS NOT DISTINCT FROM OLD.reviewed_at AND NEW.published_at IS NOT DISTINCT FROM OLD.published_at) THEN
  RAISE EXCEPTION 'Published catalog content is immutable' USING ERRCODE='55000';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER immutable_published_recipes BEFORE UPDATE OR DELETE ON nutrition.recipe_versions
 FOR EACH ROW EXECUTE FUNCTION nutrition.guard_recipe_catalog_content();
CREATE TRIGGER immutable_published_rules BEFORE UPDATE OR DELETE ON nutrition.rule_versions
 FOR EACH ROW EXECUTE FUNCTION nutrition.guard_rule_catalog_content();

REVOKE ALL ON nutrition.catalog_packages,nutrition.catalog_package_entries,nutrition.catalog_audit FROM PUBLIC;
REVOKE ALL ON SEQUENCE nutrition.catalog_audit_id_seq FROM PUBLIC;
GRANT USAGE ON SCHEMA nutrition TO nutrition_catalog_importer,nutrition_catalog_reviewer,nutrition_catalog_publisher;

CREATE FUNCTION nutrition.require_catalog_role(required_role text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
BEGIN
 IF required_role NOT IN ('nutrition_catalog_importer','nutrition_catalog_reviewer','nutrition_catalog_publisher')
    OR NOT pg_has_role(session_user,required_role,'member') THEN
  RAISE EXCEPTION 'Catalog operation requires role %',required_role USING ERRCODE='42501';
 END IF;
END $$;

CREATE FUNCTION nutrition.catalog_payload_digest(payload jsonb) RETURNS text
LANGUAGE sql IMMUTABLE STRICT SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
 SELECT encode(public.digest(convert_to(payload::text,'UTF8'),'sha256'),'hex')
$$;

CREATE FUNCTION nutrition.import_catalog_bundle(package_id uuid, package_key text, payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE
 next_version integer;
 actual_digest text;
BEGIN
 PERFORM nutrition.require_catalog_role('nutrition_catalog_importer');
 IF package_id IS NULL OR package_id='00000000-0000-0000-0000-000000000000'::uuid THEN RAISE EXCEPTION 'Package ID is required' USING ERRCODE='22023'; END IF;
 IF package_key IS NULL OR package_key !~ '^[a-z0-9]+(-[a-z0-9]+)*$' THEN RAISE EXCEPTION 'Invalid package key' USING ERRCODE='22023'; END IF;
 IF payload IS NULL OR jsonb_typeof(payload)<>'object' OR coalesce(payload->>'schemaVersion','')<>'1' OR coalesce(payload->>'packageKey','')<>package_key
    OR coalesce(jsonb_typeof(payload->'supportedScopes'),'')<>'array'
    OR coalesce(jsonb_typeof(payload->'citations'),'')<>'array'
    OR jsonb_typeof(payload->'concepts')<>'array' OR jsonb_typeof(payload->'recipes')<>'array'
    OR jsonb_typeof(payload->'rules')<>'array' THEN
  RAISE EXCEPTION 'Catalog payload failed database boundary validation' USING ERRCODE='22023';
 END IF;
 IF jsonb_array_length(payload->'supportedScopes')=0 OR jsonb_array_length(payload->'citations')=0 OR jsonb_array_length(payload->'recipes')<3 THEN
  RAISE EXCEPTION 'Catalog payload requires scope, citation and three meals' USING ERRCODE='22023';
 END IF;
 IF EXISTS (
  SELECT 1 FROM jsonb_array_elements(payload->'supportedScopes') scope
  WHERE jsonb_typeof(scope)<>'object' OR coalesce(scope->>'population','')<>'adult'
     OR coalesce(scope->>'medicationPolicy','')<>'reported_none_only'
     OR coalesce(jsonb_typeof(scope->'conditionCodes'),'')<>'array'
     OR coalesce(jsonb_typeof(scope->'blockedSpecialNeeds'),'')<>'array'
     OR NOT coalesce(scope->'blockedSpecialNeeds','[]'::jsonb) @> '["KIDNEY_DISEASE","DYSPHAGIA","TUBE_FEEDING","FLUID_RESTRICTION","ELECTROLYTE_RESTRICTION"]'::jsonb
 ) THEN RAISE EXCEPTION 'Catalog scope is outside the P0 safety boundary' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(payload->'recipes') value WHERE value->'payload'->>'mealType'='breakfast')
    OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(payload->'recipes') value WHERE value->'payload'->>'mealType'='lunch')
    OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(payload->'recipes') value WHERE value->'payload'->>'mealType'='dinner') THEN
  RAISE EXCEPTION 'Catalog payload requires breakfast, lunch and dinner' USING ERRCODE='22023';
 END IF;
 IF EXISTS (
  SELECT 1 FROM jsonb_array_elements(payload->'recipes') value
  WHERE jsonb_typeof(value)<>'object' OR coalesce(value->>'recipeId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     OR coalesce(value->>'version','') !~ '^[1-9][0-9]*$' OR coalesce(value->'payload'->>'versionId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     OR coalesce(jsonb_typeof(value->'payload'->'sources'),'')<>'array'
 ) OR EXISTS (
  SELECT 1 FROM jsonb_array_elements(payload->'rules') value
  WHERE jsonb_typeof(value)<>'object' OR coalesce(value->>'ruleId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     OR coalesce(value->>'version','') !~ '^[1-9][0-9]*$' OR coalesce(value->'payload'->>'versionId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     OR coalesce(jsonb_typeof(value->'payload'->'prerequisites'),'')<>'array'
     OR coalesce(jsonb_typeof(value->'payload'->'sources'),'')<>'array'
 ) THEN RAISE EXCEPTION 'Catalog version entry failed database boundary validation' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('nutrition.catalog.'||package_key,0));
 SELECT coalesce(max(version),0)+1 INTO next_version FROM nutrition.catalog_packages p WHERE p.package_key=import_catalog_bundle.package_key;
 actual_digest:=nutrition.catalog_payload_digest(payload);
 INSERT INTO nutrition.catalog_packages(id,package_key,version,status,payload,payload_digest,imported_by)
 VALUES(package_id,package_key,next_version,'draft',payload,actual_digest,session_user);
 INSERT INTO nutrition.catalog_audit(package_id,package_key,package_version,action,actor,payload_digest)
 VALUES(package_id,package_key,next_version,'imported',session_user,actual_digest);
 RETURN jsonb_build_object('packageId',package_id,'packageKey',package_key,'version',next_version,'status','draft','digest',actual_digest);
END $$;

CREATE FUNCTION nutrition.review_catalog_bundle(package_id uuid, expected_digest text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE package nutrition.catalog_packages%ROWTYPE;
BEGIN
 PERFORM nutrition.require_catalog_role('nutrition_catalog_reviewer');
 SELECT * INTO package FROM nutrition.catalog_packages p WHERE p.id=package_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Catalog package not found' USING ERRCODE='P0002'; END IF;
 IF package.status<>'draft' THEN RAISE EXCEPTION 'Catalog package must be draft' USING ERRCODE='55000'; END IF;
 IF package.payload_digest<>expected_digest THEN RAISE EXCEPTION 'Catalog digest changed' USING ERRCODE='40001'; END IF;
 IF package.imported_by=session_user THEN RAISE EXCEPTION 'Importer cannot review the same package' USING ERRCODE='42501'; END IF;
 UPDATE nutrition.catalog_packages SET status='reviewed',reviewed_by=session_user,reviewed_at=now() WHERE id=package_id;
 INSERT INTO nutrition.catalog_audit(package_id,package_key,package_version,action,actor,payload_digest)
 VALUES(package.id,package.package_key,package.version,'reviewed',session_user,package.payload_digest);
 RETURN jsonb_build_object('packageId',package.id,'packageKey',package.package_key,'version',package.version,'status','reviewed','digest',package.payload_digest);
END $$;

CREATE FUNCTION nutrition.publish_catalog_bundle(package_id uuid, expected_digest text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE
 package nutrition.catalog_packages%ROWTYPE;
 old_package nutrition.catalog_packages%ROWTYPE;
 entry jsonb;
 conflict_key text;
BEGIN
 PERFORM nutrition.require_catalog_role('nutrition_catalog_publisher');
 SELECT * INTO package FROM nutrition.catalog_packages p WHERE p.id=package_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Catalog package not found' USING ERRCODE='P0002'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('nutrition.catalog.'||package.package_key,0));
 IF package.status<>'reviewed' THEN RAISE EXCEPTION 'Catalog package must be reviewed' USING ERRCODE='55000'; END IF;
 IF package.payload_digest<>expected_digest OR nutrition.catalog_payload_digest(package.payload)<>expected_digest THEN RAISE EXCEPTION 'Catalog digest changed' USING ERRCODE='40001'; END IF;
 IF session_user IN (package.imported_by,package.reviewed_by) THEN RAISE EXCEPTION 'Publisher must be independent from importer and reviewer' USING ERRCODE='42501'; END IF;

 SELECT e.content_kind||':'||e.logical_id::text INTO conflict_key
 FROM nutrition.catalog_package_entries e JOIN nutrition.catalog_packages p ON p.id=e.package_id
 JOIN (
  SELECT 'recipe'::text kind,(value->>'recipeId')::uuid logical_id FROM jsonb_array_elements(package.payload->'recipes')
  UNION ALL
  SELECT 'rule',(value->>'ruleId')::uuid FROM jsonb_array_elements(package.payload->'rules')
 ) incoming ON incoming.kind=e.content_kind AND incoming.logical_id=e.logical_id
 WHERE p.status='published' AND p.package_key<>package.package_key LIMIT 1;
 IF conflict_key IS NOT NULL THEN RAISE EXCEPTION 'Published logical content belongs to another package: %',conflict_key USING ERRCODE='23505'; END IF;

 SELECT * INTO old_package FROM nutrition.catalog_packages p WHERE p.package_key=package.package_key AND p.status='published' FOR UPDATE;
 IF FOUND THEN
  UPDATE nutrition.recipe_versions r SET status='retired'
   FROM nutrition.catalog_package_entries e WHERE e.package_id=old_package.id AND e.content_kind='recipe' AND e.version_id=r.id AND r.status='published';
  UPDATE nutrition.rule_versions r SET status='retired'
   FROM nutrition.catalog_package_entries e WHERE e.package_id=old_package.id AND e.content_kind='rule' AND e.version_id=r.id AND r.status='published';
  UPDATE nutrition.catalog_packages SET status='retired',retired_by=session_user,retired_at=now(),retire_reason='superseded' WHERE id=old_package.id;
  INSERT INTO nutrition.catalog_audit(package_id,package_key,package_version,action,actor,payload_digest,metadata)
  VALUES(old_package.id,old_package.package_key,old_package.version,'superseded',session_user,old_package.payload_digest,jsonb_build_object('replacementPackageId',package.id));
 END IF;

 IF EXISTS (
  SELECT 1 FROM nutrition.concepts current
  JOIN jsonb_array_elements(package.payload->'concepts') value ON current.code=value->>'code'
  WHERE current.version>(value->>'version')::integer
     OR (current.version=(value->>'version')::integer AND (current.kind<>value->>'kind' OR current.aliases<>value->'aliases'))
 ) THEN RAISE EXCEPTION 'Concept version conflicts with published dictionary' USING ERRCODE='23505'; END IF;

 INSERT INTO nutrition.concepts(code,kind,aliases,version)
 SELECT value->>'code',value->>'kind',value->'aliases',(value->>'version')::integer
 FROM jsonb_array_elements(package.payload->'concepts') value
 ON CONFLICT(code) DO UPDATE SET kind=excluded.kind,aliases=excluded.aliases,version=excluded.version
 WHERE nutrition.concepts.version<excluded.version;

 FOR entry IN SELECT value FROM jsonb_array_elements(package.payload->'recipes') LOOP
  INSERT INTO nutrition.recipe_versions(id,recipe_id,version,status,payload,reviewed_by,reviewed_at,published_at)
  VALUES((entry->'payload'->>'versionId')::uuid,(entry->>'recipeId')::uuid,(entry->>'version')::integer,'published',entry->'payload',package.reviewed_by,package.reviewed_at,now());
  INSERT INTO nutrition.catalog_package_entries(package_id,content_kind,version_id,logical_id,version)
  VALUES(package.id,'recipe',(entry->'payload'->>'versionId')::uuid,(entry->>'recipeId')::uuid,(entry->>'version')::integer);
 END LOOP;
 FOR entry IN SELECT value FROM jsonb_array_elements(package.payload->'rules') LOOP
  INSERT INTO nutrition.rule_versions(id,rule_id,version,status,payload,reviewed_by,reviewed_at,published_at)
  VALUES((entry->'payload'->>'versionId')::uuid,(entry->>'ruleId')::uuid,(entry->>'version')::integer,'published',entry->'payload',package.reviewed_by,package.reviewed_at,now());
  INSERT INTO nutrition.catalog_package_entries(package_id,content_kind,version_id,logical_id,version)
  VALUES(package.id,'rule',(entry->'payload'->>'versionId')::uuid,(entry->>'ruleId')::uuid,(entry->>'version')::integer);
 END LOOP;
 UPDATE nutrition.catalog_packages SET status='published',published_by=session_user,published_at=now() WHERE id=package.id;
 INSERT INTO nutrition.catalog_audit(package_id,package_key,package_version,action,actor,payload_digest)
 VALUES(package.id,package.package_key,package.version,'published',session_user,package.payload_digest);
 RETURN jsonb_build_object('packageId',package.id,'packageKey',package.package_key,'version',package.version,'status','published','digest',package.payload_digest);
END $$;

CREATE FUNCTION nutrition.retire_catalog_bundle(package_id uuid, reason text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE package nutrition.catalog_packages%ROWTYPE;
BEGIN
 PERFORM nutrition.require_catalog_role('nutrition_catalog_publisher');
 SELECT * INTO package FROM nutrition.catalog_packages p WHERE p.id=package_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Catalog package not found' USING ERRCODE='P0002'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('nutrition.catalog.'||package.package_key,0));
 IF package.status<>'published' THEN RAISE EXCEPTION 'Catalog package must be published' USING ERRCODE='55000'; END IF;
 IF reason IS NULL OR length(trim(reason))<5 THEN RAISE EXCEPTION 'Retirement reason must contain at least five characters' USING ERRCODE='22023'; END IF;
 UPDATE nutrition.recipe_versions r SET status='retired'
  FROM nutrition.catalog_package_entries e WHERE e.package_id=package.id AND e.content_kind='recipe' AND e.version_id=r.id AND r.status='published';
 UPDATE nutrition.rule_versions r SET status='retired'
  FROM nutrition.catalog_package_entries e WHERE e.package_id=package.id AND e.content_kind='rule' AND e.version_id=r.id AND r.status='published';
 UPDATE nutrition.catalog_packages SET status='retired',retired_by=session_user,retired_at=now(),retire_reason=trim(reason) WHERE id=package.id;
 INSERT INTO nutrition.catalog_audit(package_id,package_key,package_version,action,actor,payload_digest,metadata)
 VALUES(package.id,package.package_key,package.version,'retired',session_user,package.payload_digest,jsonb_build_object('reason',trim(reason)));
 RETURN jsonb_build_object('packageId',package.id,'packageKey',package.package_key,'version',package.version,'status','retired','digest',package.payload_digest);
END $$;

REVOKE ALL ON FUNCTION nutrition.require_catalog_role(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION nutrition.catalog_payload_digest(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION nutrition.guard_recipe_catalog_content() FROM PUBLIC;
REVOKE ALL ON FUNCTION nutrition.guard_rule_catalog_content() FROM PUBLIC;
REVOKE ALL ON FUNCTION nutrition.import_catalog_bundle(uuid,text,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION nutrition.review_catalog_bundle(uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION nutrition.publish_catalog_bundle(uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION nutrition.retire_catalog_bundle(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION nutrition.import_catalog_bundle(uuid,text,jsonb) TO nutrition_catalog_importer;
GRANT EXECUTE ON FUNCTION nutrition.review_catalog_bundle(uuid,text) TO nutrition_catalog_reviewer;
GRANT EXECUTE ON FUNCTION nutrition.publish_catalog_bundle(uuid,text) TO nutrition_catalog_publisher;
GRANT EXECUTE ON FUNCTION nutrition.retire_catalog_bundle(uuid,text) TO nutrition_catalog_publisher;
COMMIT;
