defmodule GiocciEngineZenoh do
  @moduledoc false

  use GenServer
  require Logger

  alias GiocciEngine.ModuleDB

  def setup_engine() do
    ## 最初に指定された数のRelayノードとのZenohコネクションを作成する
    relay_number_string = System.get_env("NODE_RELAY_NUMBER")
    relay_number = String.to_integer(relay_number_string)
    create_session(relay_number)
  end

  def start_link(relay_name, number) do
    ## RelayからEngineを通ってRelayに返送するsubとpubをセットアップする
    ## EngineのZenohセッションを起動
    engine_name = System.get_env("MY_NODE_NAME")
    {:ok, session} = Zenohex.open()
    ## pub,subそれぞれのキーをたてる

    {:ok, subscriber} =
      Zenohex.Session.declare_subscriber(session, "from/" <> relay_name <> "/to/" <> engine_name)

    {:ok, publisher} =
      Zenohex.Session.declare_publisher(session, "from/" <> engine_name <> "/to/" <> relay_name)

    id_string = "Relay2Engine2Relaysession" <> number
    ## 状態として次の状態をもつ
    state = %{
      publisher: publisher,
      subscriber: subscriber,
      callback: &callback/2,
      id: String.to_atom(id_string),
      session: session
    }

    Logger.info("from/" <> relay_name <> "/to/" <> engine_name)
    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: String.to_atom(id_string))
    ## subの開始
    subscriber_loop(state)
    {:ok, state}
  end

  def callback(state, message) do
    ## Clientから送られたデータを解析して、実行する
    %{
      key_expr: erkey,
      value: message_intermediate,
      kind: kind,
      reference: reference
    } = message

    ## msgをバイナリからlistにもどす
    message_readable =
      message_intermediate
      |> String.trim()
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case message_readable do
      ## module_execの場合
      [module, function, arity, :module_exec] = message_readable ->
        #  module_execする
        module_result_reply = apply(module, function, arity)

        ## 実行結果を(Relayを通して)Clientに返す
        Zenohex.Publisher.put(
          state.publisher,
          (module_result_reply <> " from engine") |> :erlang.term_to_binary() |> Base.encode64()
        )

      ## module_saveの場合
      [encode_module, :module_save] = message_readable ->
        ## Module_Saveを保存しロードする
        module_save_reply = module_load_and_save({:module_save, encode_module})
        ## ロード結果を(Relayを通して)Clientに返す
        Zenohex.Publisher.put(
          state.publisher,
          module_save_reply |> :erlang.term_to_binary() |> Base.encode64()
        )

      _ = message_readable ->
        Logger.error(inspect("no match"))
    end
  end

  def module_load_and_save({:module_save, encode_module}) do
    {name, binary, path} =
      Giocci.CLI.ModuleConverter.decode(encode_module)

    Logger.info("v module: #{inspect(name)} is loaded.")

    name_snake =
      name
      |> Module.split()
      |> Enum.join("_")
      |> String.to_atom()

    Giocci.CLI.ModuleConverter.load({name, binary, path})
  end

  def handle_info(:loop, state) do
    # subをループするhandle_info
    subscriber_loop(state)
    {:noreply, state}
  end

  defp create_session(0) do
    :ok
  end

  defp create_session(n) do
    ## セッションをｎ個作る関数
    number = Integer.to_string(n)
    relay_name = System.get_env("NODE_RELAY_NAME" <> number)
    start_link(relay_name, number)
    create_session(n - 1)
  end

  defp subscriber_loop(state) do
    ## subを永続化する関数

    case Zenohex.Subscriber.recv_timeout(state.subscriber, 10_000) do
      {:ok, sample} ->
        state.callback.(state, sample)
        send(state.id, :loop)

      {:error, :timeout} ->
        send(state.id, :loop)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end
end
