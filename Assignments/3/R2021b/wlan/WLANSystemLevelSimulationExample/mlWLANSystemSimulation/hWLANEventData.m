classdef (ConstructOnLoad) hWLANEventData < event.EventData
%hWLANEventData Create an object derived from event.EventData class
%
%   hWLANEventData creates an object that is derived from event.Eventdata class
%
%   hWLANEventData properties:
%
%   Data - Structure input to be passed to registered listener callback

%   Copyright 2021 The MathWorks, Inc.

properties
    Data
end
end