-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.Alert (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type USER-DEFINED NOT NULL,
  severity USER-DEFINED NOT NULL,
  title character varying NOT NULL,
  description text,
  district character varying NOT NULL,
  isPublic boolean NOT NULL DEFAULT false,
  isActive boolean NOT NULL DEFAULT true,
  source character varying,
  createdAt timestamp with time zone NOT NULL DEFAULT now(),
  expiresAt timestamp with time zone,
  incidentId uuid,
  CONSTRAINT Alert_pkey PRIMARY KEY (id),
  CONSTRAINT Alert_incidentId_fkey FOREIGN KEY (incidentId) REFERENCES public.ConfirmedIncident(id)
);
CREATE TABLE public.BaseWaterLevel (
  device_id character varying NOT NULL,
  base_level double precision NOT NULL,
  set_date timestamp without time zone,
  CONSTRAINT BaseWaterLevel_pkey PRIMARY KEY (device_id),
  CONSTRAINT BaseWaterLevel_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.IoT_Device(device_id)
);
CREATE TABLE public.ConfirmedIncident (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title character varying NOT NULL,
  disasterType USER-DEFINED NOT NULL,
  district character varying NOT NULL,
  severity USER-DEFINED NOT NULL,
  status USER-DEFINED NOT NULL DEFAULT 'ACTIVE'::incident_status,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  description text,
  publicVisibility boolean NOT NULL DEFAULT true,
  affectedPeople integer NOT NULL DEFAULT 0 CHECK ("affectedPeople" >= 0),
  createdAt timestamp with time zone NOT NULL DEFAULT now(),
  updatedAt timestamp with time zone NOT NULL DEFAULT now(),
  division_id integer,
  CONSTRAINT ConfirmedIncident_pkey PRIMARY KEY (id),
  CONSTRAINT fk_confirmed_division FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.DeployableAsset (
  asset_id integer NOT NULL DEFAULT nextval('"DeployableAsset_asset_id_seq"'::regclass),
  name character varying NOT NULL,
  type character varying NOT NULL,
  status character varying NOT NULL DEFAULT 'AVAILABLE'::character varying,
  base_location character varying,
  current_latitude numeric,
  current_longitude numeric,
  CONSTRAINT DeployableAsset_pkey PRIMARY KEY (asset_id)
);
CREATE TABLE public.DispatchRecord (
  dispatch_id integer NOT NULL DEFAULT nextval('"DispatchRecord_dispatch_id_seq"'::regclass),
  asset_id integer,
  deployment_status character varying NOT NULL DEFAULT 'EN_ROUTE'::character varying,
  dispatched_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  released_at timestamp with time zone,
  incident_id uuid,
  CONSTRAINT DispatchRecord_pkey PRIMARY KEY (dispatch_id),
  CONSTRAINT DispatchRecord_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.DeployableAsset(asset_id),
  CONSTRAINT DispatchRecord_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.ConfirmedIncident(id)
);
CREATE TABLE public.Division (
  division_id integer NOT NULL DEFAULT nextval('"Division_division_id_seq"'::regclass),
  division_name character varying NOT NULL UNIQUE,
  district character varying,
  latitude numeric,
  longitude numeric,
  province character varying,
  division_population integer,
  CONSTRAINT Division_pkey PRIMARY KEY (division_id)
);
CREATE TABLE public.Division_Resources (
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  division_id integer NOT NULL UNIQUE,
  hospital_bed_capacity integer,
  emergency_shelters integer,
  ambulance_count integer,
  food_stock_tons double precision,
  clean_water_capacity_liters double precision,
  power_grid_resilience double precision,
  CONSTRAINT Division_Resources_pkey PRIMARY KEY (division_id),
  CONSTRAINT Division_Resources_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.FloodSeverity (
  severity_id integer NOT NULL DEFAULT nextval('"FloodSeverity_severity_id_seq"'::regclass),
  device_id character varying,
  timestamp timestamp without time zone,
  current_level double precision,
  base_level double precision,
  difference double precision,
  severity character varying,
  CONSTRAINT FloodSeverity_pkey PRIMARY KEY (severity_id),
  CONSTRAINT FloodSeverity_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.IoT_Device(device_id)
);
CREATE TABLE public.IncomingReport (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  source USER-DEFINED NOT NULL,
  disasterType USER-DEFINED NOT NULL,
  district character varying NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  description text NOT NULL,
  contact character varying,
  mediaUrls ARRAY,
  verificationStatus USER-DEFINED NOT NULL DEFAULT 'PENDING_REVIEW'::verification_status,
  createdAt timestamp with time zone NOT NULL DEFAULT now(),
  sosId character varying,
  deviceId character varying,
  officerNotes text,
  reviewedById uuid,
  reviewedAt timestamp with time zone,
  incidentId uuid,
  CONSTRAINT IncomingReport_pkey PRIMARY KEY (id),
  CONSTRAINT fk_incoming_report_reviewer FOREIGN KEY (reviewedById) REFERENCES public.User(id),
  CONSTRAINT fk_incoming_report_incident FOREIGN KEY (incidentId) REFERENCES public.ConfirmedIncident(id)
);
CREATE TABLE public.IoT_Device (
  device_id character varying NOT NULL,
  division_id integer,
  installation_date date,
  status character varying,
  CONSTRAINT IoT_Device_pkey PRIMARY KEY (device_id),
  CONSTRAINT IoT_Device_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.LogisticsDeployment (
  deployment_id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_request_id uuid,
  resource_plan_id uuid,
  user_id uuid NOT NULL,
  dispatched_by uuid,
  dispatched_at timestamp with time zone NOT NULL DEFAULT now(),
  status character varying NOT NULL DEFAULT 'EN_ROUTE'::character varying CHECK (status::text = ANY (ARRAY['EN_ROUTE'::character varying, 'DELIVERED'::character varying, 'FAILED'::character varying]::text[])),
  delivery_notes text,
  completed_at timestamp with time zone,
  items_dispatched jsonb,
  incident_id uuid,
  CONSTRAINT LogisticsDeployment_pkey PRIMARY KEY (deployment_id),
  CONSTRAINT LogisticsDeployment_resource_request_id_fkey FOREIGN KEY (resource_request_id) REFERENCES public.ResourceRequest(request_id),
  CONSTRAINT LogisticsDeployment_resource_plan_id_fkey FOREIGN KEY (resource_plan_id) REFERENCES public.ResourcePlan(plan_id),
  CONSTRAINT LogisticsDeployment_logistics_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.User(id),
  CONSTRAINT LogisticsDeployment_dispatched_by_fkey FOREIGN KEY (dispatched_by) REFERENCES public.User(id),
  CONSTRAINT LogisticsDeployment_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.ConfirmedIncident(id)
);
CREATE TABLE public.PersonnelAssignment (
  assignment_id uuid NOT NULL DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL,
  user_id uuid NOT NULL,
  assigned_role character varying NOT NULL,
  status character varying NOT NULL DEFAULT 'ASSIGNED'::character varying CHECK (status::text = ANY (ARRAY['ASSIGNED'::character varying, 'EN_ROUTE'::character varying, 'ON_SITE'::character varying, 'RELEASED'::character varying]::text[])),
  assigned_by uuid,
  assigned_at timestamp with time zone NOT NULL DEFAULT now(),
  released_at timestamp with time zone,
  notes text,
  CONSTRAINT PersonnelAssignment_pkey PRIMARY KEY (assignment_id),
  CONSTRAINT PersonnelAssignment_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.ConfirmedIncident(id),
  CONSTRAINT PersonnelAssignment_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.User(id),
  CONSTRAINT PersonnelAssignment_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.User(id)
);
CREATE TABLE public.PublicAlert (
  alert_id integer NOT NULL DEFAULT nextval('"PublicAlert_alert_id_seq"'::regclass),
  title character varying NOT NULL,
  message text NOT NULL,
  severity_level character varying,
  status character varying NOT NULL DEFAULT 'ACTIVE'::character varying,
  issued_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  incident_id uuid,
  CONSTRAINT PublicAlert_pkey PRIMARY KEY (alert_id)
);
CREATE TABLE public.RainfallData (
  rainfall_id integer NOT NULL DEFAULT nextval('"RainfallData_rainfall_id_seq"'::regclass),
  division_id integer,
  date date NOT NULL,
  rain_sum double precision,
  CONSTRAINT RainfallData_pkey PRIMARY KEY (rainfall_id),
  CONSTRAINT RainfallData_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.Report (
  report_id integer NOT NULL DEFAULT nextval('"Report_report_id_seq"'::regclass),
  source_channel character varying NOT NULL,
  reporter_name character varying,
  contact_info character varying,
  description text,
  media_url character varying,
  latitude numeric,
  longitude numeric,
  status character varying NOT NULL DEFAULT 'PENDING_REVIEW'::character varying,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  incident_id uuid,
  CONSTRAINT Report_pkey PRIMARY KEY (report_id)
);
CREATE TABLE public.ReportStatusAudit (
  id bigint NOT NULL DEFAULT nextval('"ReportStatusAudit_id_seq"'::regclass),
  reportId uuid NOT NULL,
  oldStatus USER-DEFINED,
  newStatus USER-DEFINED NOT NULL,
  changedBy uuid,
  changedAt timestamp with time zone NOT NULL DEFAULT now(),
  reason text,
  CONSTRAINT ReportStatusAudit_pkey PRIMARY KEY (id),
  CONSTRAINT ReportStatusAudit_reportId_fkey FOREIGN KEY (reportId) REFERENCES public.IncomingReport(id),
  CONSTRAINT ReportStatusAudit_changedBy_fkey FOREIGN KEY (changedBy) REFERENCES public.User(id)
);
CREATE TABLE public.Resource (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type USER-DEFINED NOT NULL,
  name character varying NOT NULL,
  district character varying NOT NULL,
  status USER-DEFINED NOT NULL DEFAULT 'AVAILABLE'::resource_status,
  latitude double precision,
  longitude double precision,
  capacity integer CHECK (capacity IS NULL OR capacity > 0),
  currentLoad integer,
  lastUpdated timestamp with time zone NOT NULL DEFAULT now(),
  incidentId uuid,
  CONSTRAINT Resource_pkey PRIMARY KEY (id),
  CONSTRAINT fk_resource_incident FOREIGN KEY (incidentId) REFERENCES public.ConfirmedIncident(id)
);
CREATE TABLE public.ResourcePlan (
  plan_id uuid NOT NULL DEFAULT gen_random_uuid(),
  incident_id uuid,
  requested_by uuid,
  generated_at timestamp with time zone NOT NULL DEFAULT now(),
  status character varying NOT NULL DEFAULT 'DRAFT'::character varying CHECK (status::text = ANY (ARRAY['DRAFT'::character varying, 'APPROVED'::character varying, 'EXECUTED'::character varying]::text[])),
  plan_json jsonb NOT NULL,
  divisions_analyzed integer,
  approved_by uuid,
  approved_at timestamp with time zone,
  CONSTRAINT ResourcePlan_pkey PRIMARY KEY (plan_id),
  CONSTRAINT ResourcePlan_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.ConfirmedIncident(id),
  CONSTRAINT ResourcePlan_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.User(id),
  CONSTRAINT ResourcePlan_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.User(id)
);
CREATE TABLE public.ResourceRequest (
  request_id uuid NOT NULL DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL,
  requested_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  status character varying NOT NULL DEFAULT 'PENDING'::character varying CHECK (status::text = ANY (ARRAY['PENDING'::character varying, 'APPROVED'::character varying, 'DISPATCHED'::character varying, 'FULFILLED'::character varying, 'REJECTED'::character varying]::text[])),
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  notes text,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  CONSTRAINT ResourceRequest_pkey PRIMARY KEY (request_id),
  CONSTRAINT ResourceRequest_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.ConfirmedIncident(id),
  CONSTRAINT ResourceRequest_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.User(id),
  CONSTRAINT ResourceRequest_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.User(id)
);
CREATE TABLE public.Shelter (
  shelter_id integer NOT NULL DEFAULT nextval('"Shelter_shelter_id_seq"'::regclass),
  name character varying NOT NULL,
  type character varying,
  division_id integer,
  latitude numeric,
  longitude numeric,
  max_capacity integer NOT NULL,
  current_occupancy integer NOT NULL DEFAULT 0,
  status character varying NOT NULL DEFAULT 'CLOSED'::character varying,
  contact_person character varying,
  contact_phone character varying,
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT Shelter_pkey PRIMARY KEY (shelter_id),
  CONSTRAINT Shelter_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.SoilMoisture (
  soil_id integer NOT NULL DEFAULT nextval('"SoilMoisture_soil_id_seq"'::regclass),
  division_id integer,
  date date NOT NULL,
  moisture_7_28cm double precision,
  moisture_28_100cm double precision,
  moisture_100_255cm double precision,
  CONSTRAINT SoilMoisture_pkey PRIMARY KEY (soil_id),
  CONSTRAINT SoilMoisture_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.TemperatureData (
  temp_id integer NOT NULL DEFAULT nextval('"TemperatureData_temp_id_seq"'::regclass),
  division_id integer,
  date date NOT NULL,
  temperature double precision,
  CONSTRAINT TemperatureData_pkey PRIMARY KEY (temp_id),
  CONSTRAINT TemperatureData_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.User (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  email character varying NOT NULL UNIQUE,
  name character varying NOT NULL,
  role USER-DEFINED NOT NULL DEFAULT 'PUBLIC_USER'::user_role,
  assignedDistrict character varying,
  createdAt timestamp with time zone NOT NULL DEFAULT now(),
  password_hash character varying,
  CONSTRAINT User_pkey PRIMARY KEY (id)
);
CREATE TABLE public.computed_features (
  feature_id integer NOT NULL DEFAULT nextval('computed_features_feature_id_seq'::regclass),
  division_id integer NOT NULL,
  date date NOT NULL,
  rain_lag_1 double precision,
  rain_rolling_3d double precision,
  rain_rolling_7d double precision,
  month_sin double precision,
  month_cos double precision,
  spi double precision,
  division_encoded integer,
  level_difference double precision,
  CONSTRAINT computed_features_pkey PRIMARY KEY (feature_id),
  CONSTRAINT computed_features_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.disaster_predictions (
  prediction_id integer NOT NULL DEFAULT nextval('disaster_predictions_prediction_id_seq'::regclass),
  division_id integer NOT NULL,
  feature_date date NOT NULL,
  predicted_for_date date NOT NULL,
  horizon integer NOT NULL CHECK (horizon = ANY (ARRAY[1, 2, 3])),
  hazard_type character varying NOT NULL CHECK (hazard_type::text = ANY (ARRAY['FLOOD'::character varying, 'LANDSLIDE'::character varying, 'DROUGHT'::character varying]::text[])),
  prob_normal double precision,
  prob_moderate double precision,
  prob_severe double precision,
  prob_extreme double precision,
  predicted_severity integer CHECK (predicted_severity >= 0 AND predicted_severity <= 3),
  predicted_severity_label character varying,
  run_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT disaster_predictions_pkey PRIMARY KEY (prediction_id),
  CONSTRAINT disaster_predictions_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.forecast_features (
  feature_id integer NOT NULL DEFAULT nextval('forecast_features_feature_id_seq'::regclass),
  division_id integer NOT NULL,
  date date NOT NULL,
  rain_lag_1 double precision,
  rain_rolling_3d double precision,
  rain_rolling_7d double precision,
  month_sin double precision,
  month_cos double precision,
  spi double precision,
  division_encoded integer,
  CONSTRAINT forecast_features_pkey PRIMARY KEY (feature_id),
  CONSTRAINT forecast_features_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.forecast_weather_data (
  forecast_id integer NOT NULL DEFAULT nextval('forecast_weather_data_forecast_id_seq'::regclass),
  division_id integer NOT NULL,
  date date NOT NULL,
  rain_sum double precision,
  temperature double precision,
  moisture_7_28cm double precision,
  moisture_28_100cm double precision,
  moisture_100_255cm double precision,
  fetched_at timestamp without time zone DEFAULT now(),
  CONSTRAINT forecast_weather_data_pkey PRIMARY KEY (forecast_id),
  CONSTRAINT forecast_weather_data_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);
CREATE TABLE public.iot_flood (
  id text NOT NULL,
  type text NOT NULL,
  temp numeric,
  hum integer,
  depth numeric,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT iot_flood_pkey PRIMARY KEY (id)
);
CREATE TABLE public.iot_landslide (
  id text NOT NULL,
  type text NOT NULL,
  temp numeric,
  hum integer,
  moist integer,
  ax integer,
  ay integer,
  az integer,
  gx integer,
  gy integer,
  gz integer,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT iot_landslide_pkey PRIMARY KEY (id)
);
CREATE TABLE public.iot_rainfall_data (
  row_id integer NOT NULL DEFAULT nextval('iot_rainfall_data_row_id_seq'::regclass),
  id character varying NOT NULL,
  type character varying NOT NULL DEFAULT 'FLOOD'::character varying,
  temp double precision,
  hum double precision,
  depth double precision,
  recorded_at timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT iot_rainfall_data_pkey PRIMARY KEY (row_id)
);
CREATE TABLE public.risk_alert_events (
  id bigint NOT NULL DEFAULT nextval('risk_alert_events_id_seq'::regclass),
  event_id character varying NOT NULL UNIQUE,
  event_type character varying NOT NULL DEFAULT 'risk-alert'::character varying CHECK (event_type::text = 'risk-alert'::text),
  event_timestamp timestamp with time zone NOT NULL,
  alert_id character varying NOT NULL,
  alert_type character varying NOT NULL,
  severity character varying NOT NULL CHECK (severity::text = ANY (ARRAY['LOW'::character varying, 'MEDIUM'::character varying, 'HIGH'::character varying, 'CRITICAL'::character varying]::text[])),
  title text NOT NULL,
  description text,
  district character varying,
  division_id integer,
  division_name character varying,
  forecast_date date,
  prediction_kind character varying,
  prediction_category character varying,
  prediction_probability double precision CHECK (prediction_probability IS NULL OR prediction_probability >= 0::double precision AND prediction_probability <= 1::double precision),
  top_probability_key character varying,
  probabilities jsonb,
  consideration_score double precision CHECK (consideration_score IS NULL OR consideration_score >= 0::double precision AND consideration_score <= 1::double precision),
  resource_pressure double precision CHECK (resource_pressure IS NULL OR resource_pressure >= 0::double precision AND resource_pressure <= 1::double precision),
  hazard_type character varying,
  feature_date date,
  source text,
  is_active boolean NOT NULL DEFAULT true,
  is_public boolean NOT NULL DEFAULT false,
  raw_message jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT risk_alert_events_pkey PRIMARY KEY (id),
  CONSTRAINT risk_alert_events_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.Division(division_id)
);