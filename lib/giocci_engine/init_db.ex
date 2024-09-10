defmodule GiocciEngine.InitDb do
  alias GiocciEngine.Database
  alias GiocciEngine.ModuleDB

  def all() do
    database()
    module_db()
  end

  def database() do
    init_database_map = init_database()

    CubDB.clear(Database)
    CubDB.put_multi(Database, Map.to_list(init_database_map))
  end

  def module_db() do
    init_module_db_map = init_module_db()

    CubDB.clear(ModuleDB)
    CubDB.put_multi(ModuleDB, Map.to_list(init_module_db_map))
  end

  defp init_database() do
    %{
      A34566369DFF4BB0A83B93B6B135BC8C: %{
        attr_device: "led",
        attr_type: "dout",
        contact_name: :do0,
        contact_value: 0,
        node_name: {:global, :node1}
      },
      DEDDBA778B124EA3AEA3773ACD0623FB: %{
        attr_device: "button",
        attr_type: "din",
        contact_name: :di0,
        contact_value: 0,
        node_name: {:global, :node1}
      },
      B6266273D5BF402E8078903C55987DDD: %{
        attr_device: "button",
        attr_type: "din",
        contact_name: :di0,
        contact_value: 0,
        node_name: {:global, :node2}
      },
      EE6565A21FD04B5A8C1A9E513016181F: %{
        attr_device: "button",
        attr_type: "din",
        contact_name: :di1,
        contact_value: 0,
        node_name: {:global, :node2}
      }
    }
  end

  defp init_module_db() do
    %{}
  end
end
