# Copy this file to your application project and set
# the values accordingly to use Giocci features.
# It is recommended to prepare `.env` and gitignore it
# to keep your servers information secret.

import Config
import Dotenvy

source!([".env", System.get_env()])

config :giocci_engine, :giocci_engine_zenoh,
  # The node name of your application
  my_node_name: env!("MY_ENGINE_NODE_NAME", :string, "engine1"),
  # The nodes' name for Giocci relays
  relay_node_list:
    env!("RELAY_NODE_NAME", :string, "relay1, relay2, relay3") |> String.split(~r/[ ,]+/)
