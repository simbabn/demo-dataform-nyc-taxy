const vars = dataform.projectConfig.vars;

module.exports = {
  env: vars.env,
  app_name: vars.app_name,
  raw_project_id: vars.raw_project_id,
  proc_project_id: vars.process_project_id,
  mkp_project_id: vars.marketplace_project_id,
  raw_dataset: vars.raw_dataset,
  staging_dataset: vars.staging_dataset,
  marts_dataset: vars.marts_dataset,
  assertions_dataset: vars.assertions_dataset,
  nyc_taxi_source_table: vars.nyc_taxi_source_table,
};
