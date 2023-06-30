# -*- coding:utf-8 -*-
import os
BITFILE_INT = os.path.join(os.path.dirname(__file__), 'single_shot.bit')
BITFILE_EXT = os.path.join(os.path.dirname(__file__), 'pulsegenerator1000_xem7310_extclk_200805.bit')
import json
import time
import ok
import numpy as np
import struct
from copy import copy
import matplotlib.pyplot as plt
import math
from scipy.linalg import expm
# from single_shot.data_handle import *
import scipy
import scipy.optimize
import scipy.special
# from single_shot.calculate import calculate
from scipy.optimize import curve_fit
from scipy import integrate
from numpy import array

def double_poisson(x,a, b, lamda1, lamda2):
    """double_poisson function."""
    return a * ((lamda1) ** x) * np.exp(-lamda1)/ scipy.special.factorial(x) + b * ((lamda2) ** x) * np.exp(-lamda2)/ scipy.special.factorial(x)
class PulseGenerator1000:
    """
    Represents an FPGA based Pulse Generator with 1ns resolution.
    """

    command_map = {'RUN': 0, 'LOAD': 1, 'RESET_READ': 2, 'RESET_SDRAM': 3, 'RETURN': 4,
                   'RESET_WRITE2': 5, 'RESET_WRITE3': 6, 'RESET_WRITE4': 7, 'RESET_WRITE5': 8, 'RESET_WRITE6': 9, 'RESET_WRITE7': 10,'RESET_TT': 11}
    state_map_pg = {0: 'IDLE', 1: 'RESET_READ', 2: 'RESET_SDRAM', 3: 'RESET_TT', 4: 'LOAD_0', 5: 'READ_0', 6: 'RESET_WRITE2',
                    7: 'RESET_WRITE3', 8: 'RESET_WRITE4', 9: 'RESET_WRITE5', 10: 'RESET_WRITE6',11: 'RESET_WRITE7',12:"return"}
    default_channels = {'ch0': 0, 'ch1': 1, 'ch2': 2, 'ch3': 3, 'ch4': 4, 'ch5': 5, 'ch6': 6, 'ch7': 7, 'ch8': 8,
                        'ch9': 9, 'ch10': 10, 'ch11': 11, 'ch12': 12, 'ch13': 13, 'ch14': 14, 'ch15': 15, 'ch16': 16,
                        'ch17': 17, 'ch18': 18, 'ch19': 19}

    def __init__(self, serial='', channel_map=default_channels, core='int'):
        self.serial = serial
        self.channel_map = channel_map
        assert core in ['int', 'ext']
        self._core = core
        self.n_channels = 24
        self.channel_width = 4
        self.dt = 1
        self.max_sequence_number = 1e9
        self.xem = ok.FrontPanel()
        self.default_pattern = []
        self.reset()
        # self.checkUnderflow()
        self.weight_set()
        self.probability_set()

    def open_usb(self):
        if self.xem.OpenBySerial(self.serial) != 0:
            raise RuntimeError('failed to open USB connection.')
    def checkmemory(self):
        pg.xem.UpdateWireOuts()
        addr0 =  pg.xem.GetWireOutValue(0x22) / 4
        addr2 = (pg.xem.GetWireOutValue(0x24) - 0x4000000) / 4
        print(addr2)
        if(4*addr0>=0x4000000):
            raise RuntimeError('memory0 overload.')
        # if(4*addr1>=0x4000000):
        #     raise RuntimeError('memory1 overload.')
        if(4*addr2>=0xe000000):
            raise RuntimeError('memory2 overload.')
        # if(4*addr3>=0x8000000):
        #     raise RuntimeError('memory3 overload.')
        # if(4*addr4>=0xa000000):
        #     raise RuntimeError('memory4 overload.')
        # if(4*addr5>=0xc000000):
        #     raise RuntimeError('memory5 overload.')
        # if(4*addr6>=0xe000000):
        #     raise RuntimeError('memory6 overload.')
        # if(4*addr7<0):
        #     raise RuntimeError('memory7 overload.')

    def flash_fpga(self, bitfile):
        ret = self.xem.ConfigureFPGA(str(bitfile))
        if ret != 0:
            raise RuntimeError('failed to upload bit file to fpga. Error code %i' % ret)

    def load_core(self):
        if self._core == 'int':
            self.flash_fpga(BITFILE_INT)
        elif self._core == 'ext':
            self.flash_fpga(BITFILE_EXT)
        else:
            raise ValueError('core must be "12x8" or "24x4"')
        if self.getInfo() != (24, 4):
            raise RuntimeError('FPGA core does not match.')

    def getInfo(self):
        """Returns the number of channels and channel width."""
        self.xem.UpdateWireOuts()
        ret = self.xem.GetWireOutValue(0x20)
        return ret & 0xff, ret >> 8

    def ctrlPulser(self, command):
        self.xem.ActivateTriggerIn(0x40, self.command_map[command])

    def getState(self):
        """
        Return the state of the FPGA core.

        The state is returned as a string out of the following list.

        'IDLE'
        'RESET_READ'
        'RESET_SDRAM'
        'RESET_WRITE'
        'LOAD_0'
        'READ_0'
        """
        self.xem.UpdateWireOuts()
        return self.state_map_pg[self.xem.GetWireOutValue(0x21)]


    def checkState(self, wanted):
        """Raises a 'RuntimeError' if the FPGA state is not the 'wanted' state."""
        actual = self.getState()
        if actual != wanted:
            raise RuntimeError("FPGA State Error. Expected '" + wanted + "' state but got '" + actual + "' state.")
        return actual
    def PGState(self,):
        actual = self.getState()
        print(actual)
        return actual
    def State(self):
        """Raises a 'RuntimeError' if the FPGA state is not the 'wanted' state."""
        actual = self.getState()
        return actual
    def enableTrigger(self):
        self.xem.SetWireInValue(0x00, 0xFF, 0x02)
        self.xem.UpdateWireIns()

    def disableTrigger(self):
        self.xem.SetWireInValue(0x00, 0x00, 0x02)
        self.xem.UpdateWireIns()

    def weight_set(self):
        ##08-1f
        # weigjt0
        self.xem.SetWireInValue(0x08, 0x0d294ebfd)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x09, 0x5a10e)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x0a, 0x1dde6c)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x0b, 0xeec22b4c)
        self.xem.UpdateWireIns()
        # weigjt1
        self.xem.SetWireInValue(0x0c, 0xa4124e34)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x0d, 0x00)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x0e, 0x00)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x0f, 0x427f0340)
        self.xem.UpdateWireIns()
        # weigjt2
        self.xem.SetWireInValue(0x10, 0xffaae5c0)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x11, 0x0)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x12, 0x0)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x13, 0x250a1ac0)
        self.xem.UpdateWireIns()
        # # weigjt3
        self.xem.SetWireInValue(0x14, 0x84ccb400)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x15, 0x0)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x16, 0x0)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x17, 0x6e08e00)
        self.xem.UpdateWireIns()
        # weigjt4
        self.xem.SetWireInValue(0x18, 0xcef00000)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x19, 0x00)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x1a, 0x00)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x1b, 0x3d48000)
        self.xem.UpdateWireIns()
        # weigjt5
        self.xem.SetWireInValue(0x1c, 0x80fc0000)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x1d, 0x0)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x1e, 0x0)
        self.xem.UpdateWireIns()
        self.xem.SetWireInValue(0x1f, 0xd80000)
        self.xem.UpdateWireIns()

    def probability_set(self,p1=10,p2=9,p3=10,p4=1,p5=2,p6=1,num=10000,choose=1):
        # 10ns*num
        p1=p1
        p2=p2*256
        p3=p3*65536
        p4=p4*16777216
        accuracy_max_min=p1+p2+p3+p4
        self.xem.SetWireInValue(0x04, accuracy_max_min)
        self.xem.UpdateWireIns()
        time.sleep(0.01)

        p5=p5
        p6=p6*256
        period=num*65536
        select=choose*2147483648
        accuracy_num_thre=p5+p6+period+select
        self.xem.SetWireInValue(0x02, accuracy_num_thre)
        self.xem.UpdateWireIns()
        time.sleep(0.01)

    def enableDecoder(self):
        self.xem.SetWireInValue(0x00, 0x00, 0X01)
        self.xem.UpdateWireIns()

    def disableDecoder(self):
        self.xem.SetWireInValue(0x00, 0xff, 0X01)
        self.xem.UpdateWireIns()


    def run(self,file=2):
        self.halt()
        time.sleep(0.01)
        if(file==2):
            self.xem.SetWireInValue(0x03, 0x10)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
        if(file==3):
            self.xem.SetWireInValue(0x03, 0x18)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
        if(file==4):
            self.xem.SetWireInValue(0x03, 0x20)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
        if(file==5):
            self.xem.SetWireInValue(0x03, 0x28)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
        if(file==6):
            self.xem.SetWireInValue(0x03, 0x30)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
        if(file==7):
            self.xem.SetWireInValue(0x03, 0x38)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
        time.sleep(0.01)
        self.ctrlPulser('RESET_TT')
        time.sleep(0.1)
        self.ctrlPulser('RESET_READ')
        self.ctrlPulser('RUN')
        self.enableDecoder()
        self.xem.UpdateWireOuts()
    def run_consist(self,file=2):
        time.sleep(0.01)
        self.ctrlPulser('RESET_TT')
        time.sleep(0.01)
        self.ctrlPulser('RUN')
        self.enableDecoder()

    def halt(self):
        self.disableDecoder()
        time.sleep(0.02)
        self.ctrlPulser('RETURN')
        self.checkState('IDLE')

    def loadPages(self, buf,file=0):
        if len(buf) % 1024 != 0:
            raise RuntimeError(
                'Only full SDRAM pages supported. Pad your buffer with zeros such that its length is a multiple of 1024.')

        buf = bytearray(buf)
        s = []
        self.disableDecoder()
        time.sleep(0.01)
        if(file==2):
            self.xem.SetWireInValue(0x03, 0x02)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
            self.ctrlPulser('RESET_WRITE2')
            time.sleep(0.01)
        if(file==3):
            self.xem.SetWireInValue(0x03, 0x03)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
            self.ctrlPulser('RESET_WRITE3')
            time.sleep(0.01)
        if(file==4):
            self.xem.SetWireInValue(0x03, 0x04)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
            self.ctrlPulser('RESET_WRITE4')
            time.sleep(0.01)
        if(file==5):
            self.xem.SetWireInValue(0x03, 0x05)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
            self.ctrlPulser('RESET_WRITE5')
            time.sleep(0.01)
        if(file==6):
            self.xem.SetWireInValue(0x03, 0x06)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
            self.ctrlPulser('RESET_WRITE6')
            time.sleep(0.01)
        if(file==7):
            self.xem.SetWireInValue(0x03, 0x07)
            self.xem.UpdateWireIns()
            time.sleep(0.01)
            self.ctrlPulser('RESET_WRITE7')
            time.sleep(0.01)
        self.ctrlPulser('LOAD')
        self.checkState('LOAD_0')
        byte = self.xem.WriteToBlockPipeIn(0x80, 1024, buf)
        time.sleep(0.5)
        self.checkState('LOAD_0')
        self.ctrlPulser('RETURN')
        self.checkState('IDLE')
        time.sleep(0.001)


        return byte

    def reset(self):
        self.xem = ok.FrontPanel()
        self.open_usb()
        self.load_core()
        self.setDefaultPattern(self.default_pattern)
        self.disableDecoder()
        self.ctrlPulser('RESET_TT')
        time.sleep(0.001)
        self.ctrlPulser('RESET_WRITE2')
        self.ctrlPulser('RESET_WRITE4')
        time.sleep(0.001)
        self.ctrlPulser('RESET_WRITE5')
        time.sleep(0.001)
        self.ctrlPulser('RESET_WRITE6')
        time.sleep(0.001)
        self.ctrlPulser('RESET_WRITE7')
        time.sleep(0.001)
        self.ctrlPulser('RESET_READ')
        time.sleep(0.001)
        self.ctrlPulser('RESET_SDRAM')
        time.sleep(0.01)
        self.last_download_sequence = None

    def setResetValue(self, bits):
        self.xem.SetWireInValue(0x01, bits, 0xffffffff)
        self.xem.UpdateWireIns()

    def checkUnderflow(self):
        self.xem.UpdateTriggerOuts()
        a=self.xem.IsTriggered(0x60, 1)
        print(a)
        return self.xem.IsTriggered(0x60, 1)

    def createBitsFromChannels(self, channels):
        """
        Convert a list of channel names into an array of bools of length N_CHANNELS,
        that specify the state (high or low) of each available channel.
        """
        bits = np.zeros(self.n_channels, dtype=bool)
        for channel in channels:
            bits[self.channel_map[channel]] = True
        return bits

    def setBits(self, integers, start, count, bits):
        """Sets the bits in the range start:start+count in integers[i] to bits[i]."""
        # ToDo: check bit order (depending on whether least significant or most significant bit is shifted out first from serializer)
        for i in range(self.n_channels):
            if bits[i]:
                integers[i] = integers[i] | (2 ** count - 1) << start

    def pack(self, mult, pattern,mark=0):
        # print (type(mult))
        # ToDo: check whether max repetitions is exceeded, split into several commands if necessary
        pattern = [pattern[i] | pattern[i + 1] << 4 for i in range(0, len(pattern), 2)]
        stop_num=2147483648
        if(mark==1):
            mult=stop_num+mult

        s = struct.pack('>I%iB' % len(pattern), mult, *pattern[::-1])
        # int_size = struct.calcsize("I")
        # (i,), data = struct.unpack("I", s[:int_size]), s[int_size:]

        swap = b''
        for i in range(len(s)):
            swap += bytes([s[i - 1 if i % 2 else i + 1]])
        return swap

    def adjustSequenceWithDt(self, sequence):
        newsequence = []
        sequence.reverse()
        left = 0
        dt = self.dt
        while len(sequence):
            pul = sequence.pop()
            if(len(pul)==3):
                chs, dur,mark = pul
                pul_buf=pul
            else:
                chs, dur=pul
                mark=0
                pul_buf=(chs, dur,mark)
            newdur1 = dur
            if left != 0:
                newdur1 += left
                pul_buf = (chs, newdur1)
                left = 0
            if newdur1 % dt != 0:
                newdur2 = int(np.round(newdur1 / dt)) * dt
                pul_buf = (chs, newdur2)
                left += (newdur1 - newdur2)
            newsequence.append(pul_buf)
        if left != 0:
            print('warning: there is %G ns left in the synthesis of sequence ' % left)
        return newsequence

    def convertSequenceToBinary(self, sequence, loop=True,mark=0):

        sequence = copy(sequence)
        sequence = self.adjustSequenceWithDt(sequence)
        dt = self.dt
        N_CHANNELS, CHANNEL_WIDTH = self.n_channels, self.channel_width
        ONES = 2 ** CHANNEL_WIDTH - 1
        buf = []

        # we start with an integer zero for each channel.
        # In the following, we will start filling up the bits in each of these integers
        blank = np.zeros(N_CHANNELS, dtype=int)  # we will need this many times, so we create it once and copy from this
        pattern = blank.copy()
        index = 0
        for channels, time, mark in sequence:
            ticks = int(round(time / dt))  # convert the time into an integer multiple of hardware time steps
            if ticks is 0:
                continue
            bits = self.createBitsFromChannels(channels)
            if index + ticks < CHANNEL_WIDTH:  # if pattern does not fill current block, insert into current block and continue
                self.setBits(pattern, index, ticks, bits)
                index += ticks
                continue
            if index > 0:  # else fill current block with pattern, reduce ticks accordingly, write block and start a new block
                self.setBits(pattern, index, CHANNEL_WIDTH - index, bits)
                buf.append(self.pack(0, pattern,mark))
                ticks -= (CHANNEL_WIDTH - index)
                pattern = blank.copy()
            # split possible remaining ticks into a command with repetitions and a single block for the remainder
            repetitions = int(ticks / CHANNEL_WIDTH)  # number of full blocks
            index = ticks % CHANNEL_WIDTH  # remainder will make the beginning of a new block
            if repetitions > 0:
                buf.append(self.pack(repetitions - 1, ONES * bits,mark))  # rep=0 means the block is executed once
            if index > 0:
                pattern = blank.copy()
                self.setBits(pattern, 0, index, bits)
        if loop:  # repeat the hole sequence
            if index > 0:  # fill up incomplete block with zeros and write it
                self.setBits(pattern, index, CHANNEL_WIDTH - index, np.zeros(N_CHANNELS, dtype=bool))
                buf.append(self.pack(0, pattern,mark))
        else:  # stop after one execution
            if index > 0:  # fill up the incomplete block with the bits of the last step
                self.setBits(pattern, index, CHANNEL_WIDTH - index, bits)
                buf.append(self.pack(0, pattern,mark))
            buf.append(self.pack(1 << 31, ONES * bits,mark))
            buf.append(self.pack(1 << 31, ONES * bits,mark))
        # print(buf)
        # print "buf has",len(buf)," bytes"
        buf = b''.join(buf)
        # print(len(buf)>>4)
        return b''.join([buf, ((1024 - len(buf)) % 1024) * b'\x00'])

    def Sequence(self, sequence,loop=True, write_file=0):
        """
        Output a pulse sequence.

        Input:
            sequence      List of tuples (channels, time) specifying the pulse sequence.
                          'channels' is a list of strings specifying the channels that
                          should be high and 'time' is a float specifying the time in ns.

        Optional arguments:
            loop          bool, defaults to True, specifying whether the sequence should be
                          excecuted once or repeated indefinitely.
            triggered     bool, defaults to False, specifies whether the execution
                          should be delayed until an external trigger is received
        """
        self.download(sequence, loop,file=write_file)

    last_download_sequence = None

    def download(self, sequence, loop=True, dump=True,file=0):
        """
        Download a pulse sequence but not run immediately.

        Input:
            sequence      List of tuples (channels, time) specifying the pulse sequence.
                          'channels' is a list of strings specifying the channels that
                          should be high and 'time' is a float specifying the time in ns.

        Optional arguments:
            loop          bool, defaults to True, specifying whether the sequence should be
                          excecuted once or repeated indefinitely.
        """
        if len(sequence) > self.max_sequence_number:
            raise Exception('Sequence Too Large!')
        loaded = False
        tried_times = 0
        while not loaded:
            try:
                if self.last_download_sequence == None or self.last_download_sequence != sequence or self.last_file != file:
                    self.halt()
                    # if dump:
                        # print('downloading sequence')
                    self.loadPages(self.convertSequenceToBinary(sequence, loop),file)
                    self.last_download_sequence = copy(sequence)
                    self.last_file = copy(file)
                else:
                    if dump:
                        print('sequence unchaned,skipping download')
                loaded = True
            except Exception as e:
                self.reset()
                raise e

    def setDefaultPattern(self, channels):
        """
        Set the outputs continuously high or low.

        Input:
            channels    can be an integer or a list of channel names (strings).
                        If 'channels' is an integer, each bit corresponds to a channel.
                        A channel is set to low/high when the bit is 0/1, respectively.
                        If 'channels' is a list of strings, the specified channels
                        are set high, while all others are set low.

        note that there's a but not fixed,which need to divide channel_number by 2
        """
        try:
            iterator = iter(channels)
        except:
            self.setResetValue(channels)
        else:
            bits = 0
            for channel in channels:
                bits = bits | (1 << self.channel_map[channel])
            #                 bits = bits | (1 << (self.channel_map[channel] >> 1))
            self.setResetValue(bits)
        self.halt()

    def High(self, channels):
        self.xem.SetWireInValue(0x03, 0x40)
        self.xem.UpdateWireIns()
        #         self.Sequence([(channels,1e9)]*10000, True,False)
        self.setDefaultPattern(channels)

    def Light(self):
        self.High(['laser', 'aom'])
        pass

    def Night(self):
        self.High([])

    def Open(self, mwpatt=['mw']):
        self.High(['laser'] + mwpatt)

    def clear(self):
        self.last_download_sequence = None


class TimeTagger():
    """
    Represents an FPGA based time tagger with 70ps resolution.
    """
    address_map = {'SEQUENCE_NUMBER1': 0x2b, 'RECORD_LENTH1': 0x22,'STATE': 0x2a, 'COMMAND': 0x05,
                   'DETECTION_WINDOW': 0x07, 'SEQUENCE_LENGTH': 0x06, 'DATA1': 0xa1}
    command_map = {'NAN': 0x00, 'RESET_CTR': 0x01, 'ENABLE_CTR': 0x02, 'DISABLE_CTR': 0x04, 'ENABLE_READ1': 0x08}
    state_map = {0: 'IDLE', 2: 'RUNNING', 3: 'STOPPED', 4: 'READING1'}

    def __init__(self,pg, dt=2, delay=0.072):
        self.dt = dt
        self.delay = delay
        self.xem = pg

    def command(self, cmd, wanted_state):
        #         for i in range(max_tried_times):
        self.xem.SetWireInValue(self.address_map['COMMAND'], self.command_map[cmd])
        self.xem.UpdateWireIns()
        time.sleep(0.01)
        # self.xem.SetWireInValue(self.address_map['COMMAND'], self.command_map['NAN'])
        # self.xem.UpdateWireIns()

    def TT_command(self):
        self.xem.UpdateWireOuts()
        state = self.xem.GetWireOutValue(0x2a)
        print(state)

    def configure(self, detection_window2, sequence_length, bin_width):
        self._sequence_length = sequence_length
        self._detected_clocks2 = int(detection_window2 / self.dt)
        self.xem.SetWireInValue(self.address_map['SEQUENCE_LENGTH'], self._sequence_length)
        self.xem.UpdateWireIns()
        # detection window (unit 2ns)
        self.xem.SetWireInValue(0x07, self._detected_clocks2)
        self.xem.UpdateWireIns()
        time.sleep(0.01)

    def getInfo(self):
        """Returns the detection_window and sequence_length."""
        pass

    def getState(self):
        """
        Return the state of the FPGA core.

        The state is returned as a string out of the following list.

        'IDLE'
        'RUNNING'
        'STOPPED'
        """
        self.xem.UpdateWireOuts()
        state = self.xem.GetWireOutValue(self.address_map['STATE'])
        return self.state_map[state]

    def checkState(self, wanted):
        """Raises a 'RuntimeError' if the FPGA state is not the 'wanted' state."""
        actual = self.getState()

        if actual != wanted:
            raise RuntimeError("FPGA State Error. Expected '" + wanted + "' state but got '" + actual + "' state.")

    def enable(self):
        self.command('ENABLE_CTR', 'RUNNING')

    def disable(self):
        self.xem.ActivateTriggerIn(0x40,12)
        time.sleep(0.1)
        self.command('DISABLE_CTR', 'STOPPED')
    def get_record_length1(self):
        self.xem.UpdateWireOuts()
        record_len = self.xem.GetWireOutValue(self.address_map['RECORD_LENTH1']) / 4
        return record_len

    def get_sequence_number1(self):
        self.xem.UpdateWireOuts()
        record_len = self.xem.GetWireOutValue(self.address_map['SEQUENCE_NUMBER1'])
        # print record_len,'sequences are recorded'
        return record_len

    def enable_read1(self):
        self.command('ENABLE_READ1', 'READING1')

    def reset(self):
        self.command('RESET_CTR', 'IDLE')

    buffer_len = 4096
    readbuf = bytearray(buffer_len)

    def load(self):
        f = open('lut', 'r')
        a = f.read()
        calibration_dic = eval(a)
        f.close()
        calibration_dic10 = calibration_dic[0]
        calibration_dic20 = calibration_dic[1]
        calibration_dic11 = calibration_dic[3]
        calibration_dic21 = calibration_dic[4]
        calibration_dic12 = calibration_dic[6]
        calibration_dic22 = calibration_dic[7]
        calibration_dic13 = calibration_dic[9]
        calibration_dic23 = calibration_dic[10]
        self.xem.UpdateWireOuts()
        record_size1 = self.xem.GetWireOutValue(self.address_map['RECORD_LENTH1']) / 4
        record_len = int(record_size1 * 16)
        print(record_size1, 'data are recorded')
        self.data_buf.fill(0)
        self.enable_read1()
        data1 = tt.readRaw1(record_size1)
        for i in data1:
            index_seq, a_time = i
            # print(index_seq)
            if index_seq > self.data_buf.shape[0] + 3:
                print(i, index_seq)
            bin_index = int(a_time / self._bin_width)
            if bin_index < self.data_buf.shape[1] and index_seq <= self.data_buf.shape[0]:
                self.data_buf[index_seq - 1][bin_index] += 1
        return self.data_buf


    def readRaw1(self, record_size=0,index=0):
        data = []
        readlen = record_size * 16
        readlen = int(readlen)
        #         print '1'
        while readlen > 0:
            nRead = self.xem.ReadFromBlockPipeOut(self.address_map['DATA1'], self.buffer_len, self.readbuf)
            for i in range(0, min(nRead, readlen), 16):
                data.append(self.extract2(self.readbuf))
            readlen -= self.buffer_len
        #             print data
        return data


    def extract2(self, data,index=0):
        left_equation = (int(data[index + 0]))&0xf##4+8+8+8+5
        left_equation = (left_equation << 8) | (int(data[index + 7]))
        left_equation = (left_equation << 8) | (int(data[index + 6]))
        left_equation = (left_equation << 8) | (int(data[index + 5]))
        left_equation = ((left_equation << 8) | ((int(data[index + 4]))&0xf8))>>3

        right_equatioin=  ((int(data[index + 4]))&0x7)##3+8+8+8+6
        right_equatioin = (right_equatioin << 8) | (int(data[index + 11]))
        right_equatioin = (right_equatioin << 8) | (int(data[index + 10]))
        right_equatioin = (right_equatioin << 8) | (int(data[index + 9]))
        right_equatioin = ((right_equatioin << 8) | ((int(data[index + 8]))&0xfc))>>2
        try:
            p=round(left_equation/right_equatioin,3)
        except:
            p=0

        num_photo = (int(data[index + 8]))&0x3##2+8+8+6
        num_photo = (num_photo << 8) | (int(data[index + 15]))
        num_photo = (num_photo << 8) | (int(data[index + 14]))
        num_photo = ((num_photo << 8) | ((int(data[index+ 13]))&0xfc))>>2
        return (num_photo,p)



########## TESTCODE############


if __name__ == '__main__':
    def test_micro():
        # f = open('data_create0_arrival_data.txt','r')
        # data = json.load(f)
        # f.close()
        f = open('exp_data', 'r')
        a = f.read()
        data = eval(a)
        result=[]
        error=0
        pg = PulseGenerator1000(serial='1935000RRC', core='int')
        tt = TimeTagger(pg.xem)
        for i in range(1):
            # print(i)
            pg.xem.Close()
            pg = PulseGenerator1000(serial='1935000RRC', core='int')
            tt = TimeTagger(pg.xem)
            time.sleep(0.1)
            pg.weight_set()
            t = 2000
            pg.probability_set(num=int(t / 10))  ##max母，max分子，min分母，min分子，间隔（10ns*num）
            sequence = []
            w=i
            # time_sequence=data[str(w)]
            time_sequence=data[w]
            # print(time_sequence)
            num_20=sum(time_sequence)
            sequence.append(([], t))  ##start_single
            sequence.append((['ch0'], t))  ##start_single
            for j in range(50):
                if(time_sequence[j]==0):
                    sequence.append((['ch0'], t))  ###photo
                if(time_sequence[j]==1):
                    sequence.append((['ch0','ch2'], t/2))  ###photo
                    sequence.append((['ch0'], t / 2))  ###photo
                if(time_sequence[j]==2):
                    sequence.append((['ch0','ch2'], t/4))  ###photo
                    sequence.append((['ch0'], t/4))  ###photo
                    sequence.append((['ch0','ch2'], t/4))  ###photo
                    sequence.append((['ch0'], t/4))  ###photo
                if(time_sequence[j]>=3):
                    sequence.append((['ch0','ch2'], t/8))  ###photo
                    sequence.append((['ch0'], t/8))  ###photo
                    sequence.append((['ch0','ch2'], t/8))  ###photo
                    sequence.append((['ch0'], t/8))  ###photo
                    sequence.append((['ch0','ch2'], t/8))  ###photo
                    sequence.append((['ch0'], t/8))  ###photo
                    sequence.append((['ch0'], t/8))  ###photo
                    sequence.append((['ch0'], t/8))  ###photo
            sequence.append((['ch0','ch8'], t))  ##stop
            pg.Sequence(sequence,loop=True,write_file=2)
            # pg.checkmemory()
            # pg.checkUnderflow()
            tt.configure(1000000, 300, 2)
            num = 1
            for k in range(num):
                dict = {}
                time.sleep(0.1)
                tt.reset()
                tt.enable()
                pg.run(file=2)
                # pg.checkUnderflow()
                time.sleep(0.)
                tt.disable()
                time.sleep(0.1)
                record_size1 = tt.get_record_length1()
                print(record_size1, ' records1 are saved')
                tt.enable_read1()
                time.sleep(0.1)
                data1 = tt.readRaw1(record_size1)
                time.sleep(0.1)
                try:
                    if(data1[0][1]>0.80):
                        result.append(num_20)
                        print(num_20,i)
                except:
                    a=tt.getState()
                    print(a)
                    f = open('result_selsect', 'w')
                    f.write(str(result))
                    f.close()
            # if(i%50==0):
            #     f = open('result_selsect', 'w')
            #     f.write(str(result))
            #     f.close()
            #
            #     f = open('result_selsect', 'r')
            #     a = f.read()
            #     result = eval(a)
            #     # print(result)
            #     f.close()
            #     plot = {}
            #     for i in range(100):
            #         plot[i] = 0
            #         for j in result:
            #             if (i == j):
            #                 plot[i] = plot[i] + 1
            #     x_lut = []
            #     y_lut_NV = []
            #     for i in range(100):
            #         x_lut.append(i)
            #         y_lut_NV.append(plot[i])
            #     popt0, pcov0 = curve_fit(double_poisson, x_lut, y_lut_NV)
            #     a0 = popt0[0]
            #     b0 = popt0[1]
            #     lamda10 = popt0[2]
            #     lamda20 = popt0[3]
            #     yvals10 = double_poisson(x_lut, a0, b0, lamda10, lamda20)  # 拟合y值
            #     plt.plot(x_lut,y_lut_NV, color='blue')
            #     plt.plot(x_lut,yvals10, color='red')
            #     def f(x):
            #         return a0 * ((lamda10) ** x) * np.exp(-lamda10) / scipy.special.factorial(x)
            #
            #     k1 = integrate.quad(f, 0, 100)
            #
            #     def f(x):
            #         return b0 * ((lamda20) ** x) * np.exp(-lamda20) / scipy.special.factorial(x)
            #
            #     k2 = integrate.quad(f, 0, 100)
            #     print(max(k1[0],k2[0])/(k2[0]+k1[0]),'拟合')
            #     plt.pause(10)



    def test_laser():
        pg.High(['ch0'])
    def test_freq():
        pg.checkUnderflow()
        sequence = [(['ch0'], 1000), ([], 1000)] * 100000
        pg.Sequence(sequence, loop=True)


    # pg = PulseGenerator1000(serial='1935000RSU',core='int')
    # tt = TimeTagger(pg.xem)
    test_micro()











