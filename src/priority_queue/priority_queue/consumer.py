import pika

from .constants import (
    RABBIT_MQ_HOST as HOST,
    RABBIT_MQ_PORT as PORT,
    DEFAULT_EXCHANGER_NAME as EXCHANGER,
    DEFAULT_EXCHANGER_TYPE as EX_TYPE,
    DEFAULT_QUEUE_SERVER_TO_BROKER as QUEUE_S_TO_B,
    DEFAULT_QUEUE_BROKER_TO_SERVER as QUEUE_B_TO_S,
)


class Consumer:
    """
    Consumer class used by the Service-broker
    """

    def __init__(self, host=HOST, port=PORT, exchanger=EXCHANGER,
                 exchanger_type=EX_TYPE):
        # Establish a connection with the RabbitMQ server.
        self.__create_connection(host, port)
        self.__create_channel(exchanger, exchanger_type)

        # Create the queues (same for both Producer and Consumer)
        self.__create_queue(QUEUE_S_TO_B)
        self.__create_queue(QUEUE_B_TO_S)

        # Bind the queue to the exchange agent, without a routing/binding key
        # May be not needed without a routing/binding key
        self.__channel.queue_bind(exchange=EXCHANGER,
                                  queue=QUEUE_S_TO_B)

        self.__channel.queue_bind(exchange=EXCHANGER,
                                  queue=QUEUE_B_TO_S)

    def __del__(self):
        if self.__connection.is_open:
            self.__connection.close()

    def __create_connection(self, host, port):
        self.__parameters = pika.ConnectionParameters(host=host, port=port)
        self.__connection = pika.BlockingConnection(self.__parameters)

    def __create_channel(self, exchange, exchange_type):
        if self.__connection.is_open:
            self.__channel = self.__connection.channel()
            self.__channel.exchange_declare(exchange=exchange,
                                            exchange_type=exchange_type)

    def __create_queue(self, queue, durability=False):
        if self.__connection.is_open and self.__channel.is_open:
            self.__channel.queue_declare(queue=queue, durable=durability)

    # Configure the basic consume method for a queue
    # Continuously consumes workspaces from the "queue"
    def __basic_consume(self, queue, callback, auto_ack=False):
        # 'callback' is the function to be called
        # when consuming from the queue
        self.__channel.basic_consume(queue=queue,
                                     on_message_callback=callback,
                                     auto_ack=auto_ack)

    # Consumes a single message from the channel
    def __single_consume(self, queue):
        method_frame, header_frame, body = self.__channel.basic_get(queue)
        if method_frame:
            # print(f"{method_frame}, {header_frame}, {body}")
            self.__channel.basic_ack(method_frame.delivery_tag)
            return body
        else:
            # print(f"No message returned")
            return None

    def set_callback(self, callback):
        self.__basic_consume(queue=QUEUE_S_TO_B, callback=callback, auto_ack=True)

    # Wrapper for __single_consume
    def single_consume(self):
        return self.__single_consume(QUEUE_S_TO_B)

    # TODO: Create a new class named MessageExchanger
    # This is needed, since we already have two-way communication
    # The consumer (service-broker) also publishes messages back to the producer (operandi-server)
    def reply_job_id(self, cluster_job_id, durable=False):
        if durable:
            delivery_mode = pika.spec.PERSISTENT_DELIVERY_MODE
        else:
            delivery_mode = pika.spec.TRANSIENT_DELIVERY_MODE

        message_properties = pika.BasicProperties(
            delivery_mode=delivery_mode
        )

        # Publish the message body through the exchanger agent
        self.__channel.basic_publish(exchange=EXCHANGER,
                                     routing_key=QUEUE_B_TO_S,
                                     body=cluster_job_id,
                                     properties=message_properties,
                                     mandatory=True)

    # TODO: implement proper start/stop methods
    def start_consuming(self):
        print(f"INFO: Waiting for messages. To exit press CTRL+C.")
        self.__channel.start_consuming()

    def stop_consuming(self):
        print(f"INFO: The consumer has stopped consuming.")
        self.__channel.stop_consuming()
