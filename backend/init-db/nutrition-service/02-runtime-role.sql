-- Chạy qua psql với app_password từ secret môi trường; không dùng cho DB CareSitter.
CREATE ROLE nutrition_app LOGIN PASSWORD :'app_password';
GRANT CONNECT ON DATABASE nutrition TO nutrition_app;
GRANT USAGE ON SCHEMA nutrition TO nutrition_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON nutrition.assessments,nutrition.assessment_jobs,
 nutrition.recommendations,nutrition.meal_plans,nutrition.preferences TO nutrition_app;
GRANT SELECT ON nutrition.recipe_versions,nutrition.rule_versions,nutrition.concepts TO nutrition_app;
-- FOR SHARE bảo vệ catalog epoch trong thao tác ghi ngắn; role không có quyền publish.
GRANT SELECT,UPDATE(id) ON nutrition.catalog_state TO nutrition_app;
