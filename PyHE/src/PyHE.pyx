#    Copyright (C) 2015  Grant Frame
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

from libcpp.vector cimport vector
from libcpp.string cimport string
from libcpp cimport bool
		
cdef extern from "../../BGV_HE/BGV_HE.h":
    cdef cppclass BGV_HE:
        BGV_HE() except +

        void keyGen(long p, long r, long L, long c,
            long w, long d, long security, long m,
            const vector[long]& gens, const vector[long]& ords) except +
        string encrypt(vector[long] ptxt_vect) except +
        vector[long] decrypt(string key) except +


        string set(string key) except +
        void addCtxt(string key, string other_key, bool negative) except +
        void multiplyBy(string key, string other_key) except +
        void multiplyBy2(   string key,
                            string other_key1,
                            string other_key2) except +
        void square(string key) except +
        void cube(string key) except +
        void negate(string key) except +
        bool equalsTo(string key, string other_key, bool comparePkeys)
        void rotate(string key, long k) except +
        void shift(string key, long k) except +


        long numSlots() except +
        void erase(string key) except +


        void timersOn() except +
        void timersOff() except +
        void resetTimers() except +
        void printTimers() except +

from PyPtxt import PyPtxt
from PyCtxt import PyCtxt
from PyCtxt import PyCtxtLenError
cdef class PyHE:
    cdef BGV_HE *thisptr
    cdef long modulus

    def __cinit__(self):
        self.thisptr = new BGV_HE()
    def __dealloc__(self):
        del self.thisptr

    ########################################################################

    def keyGen(self, run_params):
        cdef vector[long] gens;
        cdef vector[long] ords;

        for elt in run_params["gens"]:
            gens.push_back(elt)

        for elt in run_params["ords"]:
            ords.push_back(elt)

        self.thisptr.keyGen( run_params["p"],
                             run_params["r"],
                             run_params["L"],
                             run_params["c"],
                             run_params["w"],
                             run_params["d"],
                             run_params["security"],
                             run_params["m"],
                             gens, ords)

        self.modulus = run_params["p"]

    # for each list of size numSlots in PyPtxt object encrypt the list
    # and then append the key to a PyCtxt object
    def encrypt(self, ptxt, fill=0):
        if not isinstance(ptxt, PyPtxt):
            raise TypeError("encrypt error ptxt wasn't of type PyPtxt")

        cdef vector[long] ptxtVect;
        numSlots = self.numSlots()
        ptxtLen = ptxt.numSlots()
        if numSlots < ptxtLen:
            raise ValueError("PyHE encrypt error: input list has more "
                             "elements than number of plaintext slots")

        ctxt = PyCtxt(ptxt.getPyHE(), ptxt.getPtxtLen())

        for elt in ptxt.getPtxtList():
            ptxtVect.clear()

            eltLen = len(elt)
            for i in range(numSlots):
                if i < eltLen:
                    ptxtVect.push_back(elt[i])
                else:
                    ptxtVect.push_back(fill)

            ctxt.appendKey(self.thisptr.encrypt(ptxtVect))

        return ctxt

    # for each key in the PyCtxt object decrypt the Ctxt corresponding to that
    # key. Then concatenate all the lists together to create a single list.
    # Finally slice the list to be the same size as the original list that
    # this PyCtxt encrypted.
    def decrypt(self, ctxt):
        if not isinstance(ctxt, PyCtxt):
            raise TypeError("PyHE decrypt error: ctxt must be of type PyCtxt "
                            "instead of type " + str(type(ctxt)))

        retList = []
        cdef vector[long] retVect
        keys = ctxt.getKeys()
        for key in keys:
            retVect = self.thisptr.decrypt(key)

            numSlots = self.numSlots()
            for i in range(numSlots):
                retList.append(retVect[i])

        return retList[:ctxt.getLen()]

    ########################################################################

    # Create a new PyCtxt object with the same initial parameters as ctxt
    # then copy all keys over and return new PyCtxt object.
    def set(self, ctxt):
        if not isinstance(ctxt, PyCtxt):
            raise TypeError("PyHE set error: ctxt must be of type PyCtxt "
                            "instead of type " + str(type(ctxt)))

        keys = ctxt.getKeys()
        new_ctxt = PyCtxt(ctxt.getPyHE(), ctxt.getLen())
        for key in keys:
            new_ctxt.appendKey(self.thisptr.set(key))

        return new_ctxt

    # Perform add for PyCtxt ctxt to PyCtxt otherCtxt for each key in both
    def addCtxt(self, ctxt, otherCtxt, neg=False):
        if not isinstance(ctxt, PyCtxt):
            raise TypeError("PyHE addCtxt error: ctxt must be of type PyCtxt "
                            "instead of type " + str(type(ctxt)))
        if not isinstance(otherCtxt, PyCtxt):
            raise TypeError("PyHE addCtxt error: otherCtxt must be of "
                            "type PyCtxt instead of type " +
                            str(type(otherCtxt)))

        keys = ctxt.getKeys()
        otherKeys = otherCtxt.getKeys()

        if len(keys) != len(otherKeys):
            raise PyCtxtLenError()

        numKeys = len(keys)
        for i in range(numKeys):
            self.thisptr.addCtxt(keys[i], otherKeys[i], neg)

    # Perform mult for PyCtxt ctxt to PyCtxt otherCtxt for each key in both
    def multiplyBy(self, ctxt, otherCtxt):
        if not isinstance(ctxt, PyCtxt):
            raise TypeError("PyHE multiplyBy error: ctxt must be of type PyCtxt "
                            "instead of type " + str(type(ctxt)))
        if not isinstance(otherCtxt, PyCtxt):
            raise TypeError("PyHE multiplyBy error: otherCtxt must be of "
                            "type PyCtxt instead of type " +
                            str(type(otherCtxt)))

        keys = ctxt.getKeys()
        otherKeys = otherCtxt.getKeys()

        if len(keys) != len(otherKeys):
            raise PyCtxtLenError()

        numKeys = len(keys)
        for i in range(numKeys):
            self.thisptr.multiplyBy(keys[i], otherKeys[i])

    # Perform multBy2 for PyCtxt ctxt to PyCtxt otherCtxt for each key in both
    def multiplyBy2(self, ctxt, otherCtxt1, otherCtxt2):
        if not isinstance(ctxt, PyCtxt):
            raise TypeError("PyHE multiplyBy2 error: ctxt must be of type PyCtxt "
                            "instead of type " + str(type(ctxt)))
        if not isinstance(otherCtxt1, PyCtxt):
            raise TypeError("PyHE multiplyBy2 error: otherCtxt1 must be of "
                            "type PyCtxt instead of type " +
                            str(type(otherCtxt1)))
        if not isinstance(otherCtxt2, PyCtxt):
            raise TypeError("PyHE multiplyBy2 error: otherCtxt2 must be of "
                            "type PyCtxt instead of type " +
                            str(type(otherCtxt2)))

        keys = ctxt.getKeys()
        otherKeys1 = otherCtxt1.getKeys()
        otherKeys2 = otherCtxt2.getKeys()

        if (len(keys) != len(otherKeys1)) and \
                (len(keys) != len(otherKeys2)):
            raise PyCtxtLenError()

        numKeys = len(keys)
        for i in range(numKeys):
            self.thisptr.multiplyBy2(keys[i], otherKeys1[i], otherKeys2[i])

    # Perform square for PyCtxt ctxt for each key in it
    def square(self, ctxt):
        if not isinstance(ctxt, PyCtxt):
            raise TypeError("PyHE square error: ctxt must be of type PyCtxt "
                            "instead of type " + str(type(ctxt)))

        keys = ctxt.getKeys()
        numKeys = len(keys)

        for i in range(numKeys):
            self.thisptr.square(keys[i])

    # Perform cube for PyCtxt ctxt for each key in it
    def cube(self, ctxt):
        if not isinstance(ctxt, PyCtxt):
            raise TypeError("PyHE cube error: ctxt must be of type PyCtxt "
                            "instead of type " + str(type(ctxt)))

        keys = ctxt.getKeys()
        numKeys = len(keys)

        for i in range(numKeys):
            self.thisptr.cube(keys[i])

    # Perform negate for PyCtxt ctxt for each key in it
    def negate(self, ctxt):
        if not isinstance(ctxt, PyCtxt):
            raise TypeError("PyHE negate error: ctxt must be of type PyCtxt "
                            "instead of type " + str(type(ctxt)))

        keys = ctxt.getKeys()
        numKeys = len(keys)

        for i in range(numKeys):
            self.thisptr.negate(keys[i])

    # Check if ctxt == otherCtxt
    def equalsTo(self, ctxt, otherCtxt, comparePkeys=True):
        if not isinstance(ctxt, PyCtxt):
            raise TypeError("PyHE equalsTo error: ctxt must be of type PyCtxt "
                            "instead of type " + str(type(ctxt)))
        if not isinstance(otherCtxt, PyCtxt):
            raise TypeError("PyHE equalsTo error: otherCtxt must be of "
                            "type PyCtxt instead of type " +
                            str(type(otherCtxt)))

        keys = ctxt.getKeys()
        otherKeys = otherCtxt.getKeys()

        numKeys = len(keys)
        for i in range(numKeys):
            if self.thisptr.equalsTo(keys[i], otherKeys[i], comparePkeys):
                continue
            else:
                return False

        return True

    ########################################################################

    # Helper Functions

    def numSlots(self):
        return self.thisptr.numSlots()
    def getModulus(self):
        return self.modulus
    def delete(self, ctxt):
        keys = ctxt.getKeys()

        for key in keys:
            self.thisptr.erase(key)


    ########################################################################

    # Timing Functions

    def timersOn(self):
        self.thisptr.timersOn()
    def timersOff(self):
        self.thisptr.timersOff()
    def resetTimers(self):
        self.thisptr.resetTimers()
    def printTimers(self):
        self.thisptr.printTimers()
