defmodule GiocciEngineZenoh do
  @moduledoc false

  use GenServer
  require Logger

  @doc """
  最初に指定されたRelayノードとのZenohコネクションを作成する
  """
  def setup_engine() do
    create_session(relay_node_list())
  end

  @doc """
    RelayからEngineを通ってRelayに返送するsubとpubを作成する
  """
  def start_link(relay_name) do
    engine_name = my_engine_node_name()
    ## EngineのZenohセッションを起動
    {:ok, session} = Zenohex.open()

    ## pub,subそれぞれのキーをたてる
    {:ok, subscriber} =
      Zenohex.Session.declare_subscriber(
        session,
        "key_prefix/giocci/relay_to_engine/" <> relay_name <> "/" <> engine_name
      )

    {:ok, publisher} =
      Zenohex.Session.declare_publisher(
        session,
        "key_prefix/giocci/engine_to_relay/" <> engine_name <> "/" <> relay_name
      )

    id_string = engine_name
    ## 状態として次の状態をもつ
    state = %{
      publisher: publisher,
      subscriber: subscriber,
      callback: &callback/2,
      id: String.to_atom(id_string),
      session: session
    }

    Logger.info("key_prefix/giocci/relay_to_engine/" <> engine_name)
    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
    ## subの開始
    subscriber_loop(state)
    {:ok, state}
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  @doc """
  ##   Clientから送られたデータを解析して、実行する
  """
  def callback(state, message) do
    ## msgをバイナリからlistにもどす
    message_readable =
      Map.get(message, :value)
      |> String.trim()
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case message_readable do
      ## module_execの場合
      [module, function, arity, :module_exec] ->
        #  module_execする
        module_result_reply = apply(module, function, arity)
        ## 実行結果を(Relayを通して)Clientに返す
        Zenohex.Publisher.put(
          state.publisher,
          [module_result_reply, " from engine"] |> :erlang.term_to_binary() |> Base.encode64()
        )

      ## module_saveの場合
      [encode_module, :module_save] ->
        ## Module_Saveを保存しロードする
        module_save_reply = module_load_and_save({:module_save, encode_module})
        ## ロード結果を(Relayを通して)Clientに返す
        Zenohex.Publisher.put(
          state.publisher,
          module_save_reply |> :erlang.term_to_binary() |> Base.encode64()
        )

      _ ->
        Logger.error(inspect("no match"))
    end
  end

  def module_load_and_save({:module_save, encode_module}) do
    {name, binary, path} =
      Giocci.CLI.ModuleConverter.decode(encode_module)

    Logger.info("v module: #{inspect(name)} is loaded.")

    Giocci.CLI.ModuleConverter.load({name, binary, path})
  end

  ##   subをループするhandle_info
  def handle_info(:loop, state) do
    subscriber_loop(state)
    {:noreply, state}
  end

  defp create_session([]) do
    :ok
  end

  ## セッションを作る関数
  defp create_session(relay_list) do
    [relay_name | tail] = relay_list
    start_link(relay_name)
    create_session(tail)
  end

  ##  subを永続化する関数
  defp subscriber_loop(state) do
    case Zenohex.Subscriber.recv_timeout(state.subscriber, 10_000) do
      {:ok, sample} ->
        state.callback.(state, sample)
        send(state.id, :loop)

      {:error, :timeout} ->
        send(state.id, :loop)

      {:error, error} ->
        Logger.error(inspect(error))

      {_, _} ->
        Logger.error("unexpected error")
    end
  end

  defp my_engine_node_name(),
    do: Application.fetch_env!(:giocci_engine, :giocci_engine_zenoh)[:my_node_name]

  defp relay_node_list(),
    do: Application.fetch_env!(:giocci_engine, :giocci_engine_zenoh)[:relay_node_list]

  defp key_prefix(),
    do: Application.fetch_env!(:giocci_engine, :giocci_engine_zenoh)[:key_prefix]
end
