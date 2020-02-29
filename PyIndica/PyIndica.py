import zmq
import traceback
import json
import pandas as pd
import time
from abc import abstractmethod


class PyIndicaServer:
    # ------------------------------------------------------------
    # ................................. initialization
    def __init__(self, ip='*', port='5556', protocol='tcp', verbose=False):
        """
        Parameters
        ----------
        ip : str
        port : str
        protocol : {'tcp','udp'}
        verbose : bool
        """

        self.__set_defaults__()
        self.ip = ip
        self.port = str(port)
        self.protocol = protocol
        self.verbose = verbose
        self.network_path = "{}://{}:{}".format(protocol, ip, port)
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REP)
        self.socket.setsockopt(zmq.LINGER, 0)
        self.socket.setsockopt(zmq.IMMEDIATE, 1)
        self.socket.bind(self.network_path)
        self.do_run = False
        print('server running at', self.network_path)

    # .................................
    def __set_defaults__(self):
        self.__resp_empty__ = {'type': 'resume'}
        self.__resp_error__ = {'type': 'error'}

    # ------------------------------------------------------------
    # ................................. routines
    def run(self):
        self.do_run = True
        while self.do_run:
            self.listen()

    # .................................
    def listen(self):
        try:
            message = self.__retrieve__()
            message = self.__parse__(message)
            if self.verbose:
                print('receive:', message)
            data = pd.DataFrame.from_dict(message)
            if self.verbose:
                print('data:', data)
            resp = self.calculation(data)
            if self.verbose:
                print('response:', resp)
            self.__response__(resp)
            return 0
        except Exception as E:
            self.__response__(self.__resp_error__)
            print('[Exception] following exception occurred:')
            traceback.print_tb(E.__traceback__)
            print(E)
            return E

    # .................................
    def __retrieve__(self):
        try:
            message = self.socket.recv()
        except zmq.error.ZMQError as E:
            if E.errno == 156384763:
                self.__response__(self.__resp_empty__)
                message = self.socket.recv()
            else:
                raise Exception(E)
        return message

    def __parse__(self, message):
        type(self)
        message = str(message)[2:-1]
        message = json.loads(message)
        return message

    def __response__(self, message):
        if message is None:
            message = self.__resp_empty__
        if type(message) is not dict:
            message = {'value': message}
        if 'type' not in message.keys():
            message['type'] = 'ok'
        message = json.dumps(message)
        time.sleep(1e-3)
        self.socket.send_string(message)

    # ------------------------------------------------------------
    # ................................. request handlers
    @abstractmethod
    def calculation(self, data):
        dict(data)
        return self.__resp_empty__
