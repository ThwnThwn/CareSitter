-- Bao dam trigger review hoat dong voi moi connection search_path.
-- Function cu goi refresh_caregiver_rating khong kem schema nen co the loi
-- khi request khong dat search_path=support,public.
CREATE OR REPLACE FUNCTION support.refresh_caregiver_rating(p_caregiver_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE people.caregiver_profiles caregiver
  SET rating_count = (
        SELECT count(*)
        FROM support.reviews review
        WHERE review.caregiver_id = p_caregiver_id
      ),
      rating_avg = COALESCE((
        SELECT round(avg(review.rating), 2)
        FROM support.reviews review
        WHERE review.caregiver_id = p_caregiver_id
      ), 0)
  WHERE caregiver.id = p_caregiver_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION support.sync_caregiver_rating()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM support.refresh_caregiver_rating(OLD.caregiver_id);
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.caregiver_id IS DISTINCT FROM NEW.caregiver_id THEN
    PERFORM support.refresh_caregiver_rating(OLD.caregiver_id);
  END IF;

  PERFORM support.refresh_caregiver_rating(NEW.caregiver_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
