defmodule Cdp.TestResult do
  use Timex
  use Ecto.Model
  import Tirexs.Bulk
  import Tirexs.Search

  queryable "test_results" do
    belongs_to(:device, Cdp.Device)
    field :created_at, :datetime
    field :updated_at, :datetime
    field :data, :binary
  end

  def create_in_db(device, data) do
    now = Cdp.DateTime.now
    test_result = Cdp.TestResult.new [
      device_id: device.id,
      data: data,
      created_at: now,
      updated_at: now,
    ]
    Cdp.Repo.create(test_result)
  end

  def create_in_elasticsearch(device, json_data) do
    {:ok, data} = JSON.decode json_data
    data = Dict.put data, :type, "test_result"
    data = Dict.put data, :created_at, (DateFormat.format!(Date.now, "{ISO}"))

    settings = Tirexs.ElasticSearch.Config.new()
    institution_id = device.laboratory.get.institution_id
    Tirexs.Bulk.store [index: Cdp.Institution.elasticsearch_index_name(institution_id), refresh: true], settings do
      create data
    end
  end

  # def enqueue_in_rabbit(device, data) do
  #   subscribers = Cdp.Subscriber.find_by_institution_id(device.institution_id)

  #   amqp_config = Cdp.Dynamo.config[:rabbit_amqp]
  #   amqp = Exrabbit.Utils.connect
  #   channel = Exrabbit.Utils.channel amqp
  #   Exrabbit.Utils.declare_exchange channel, amqp_config[:subscribers_exchange]
  #   Exrabbit.Utils.declare_queue channel, amqp_config[:subscribers_queue], true
  #   Exrabbit.Utils.bind_queue channel, amqp_config[:subscribers_queue], amqp_config[:subscribers_exchange]

  #   Enum.each subscribers, fn(s) ->
  #     IO.puts s.id
  #     {:ok, message} = JSON.encode([test_result: data, subscriber: s.id])
  #     Exrabbit.Utils.publish channel, amqp_config[:subscribers_exchange], "", message
  #   end
  # end

  def create_and_enqueue(device_key, data) do
    device = Cdp.Device.find_by_key(device_key)

    Cdp.TestResult.create_in_db(device, data)
    Cdp.TestResult.create_in_elasticsearch(device, data)
    # Cdp.TestResult.enqueue_in_rabbit(device, data)
  end

  def since(date) do

    articles = search [index: "_all"] do

      query do
        range "created_at", from: date, include_lower: true
      end

      sort do
        [
          [created_at: "asc"]
        ]
      end
    end

    result = Tirexs.Query.create_resource(articles)

    # Enum.each result.hits, fn(item) ->
    #   IO.puts inspect(item)
    #   #=> [{"_index","articles"},{"_type","article"},{"_id","2"},{"_score",1.0},{"_source",[{"id",2}, {"title","Two"},{"tags",["elixir","r uby"]},{"type","article"}]}]
    # end
    result.hits
  end
end