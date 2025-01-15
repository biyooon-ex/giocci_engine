import Config

config :giocci_engine_zenoh, :system_variables,
  my_node_name: "engine1",
  relay_node_name: ["relay1"]

config :giocci_engine, :system_variables,
  node_name: "engine",
  node_ipaddr: "192.168.10.101",
  cookie: "idkp",
  inet_dist_listen_min: "9100",
  inet_dist_listen_max: "9155",
  my_process_name: "{:global, :engine}"

# import_config "#{config_env()}.exs"
