function [macAddr, nodeID] = hNodeInfo(opType, inputParam)
%hNodeInfo Returns MAC address or node identifier based on specified
%operation type (opType) and input parameter (inputParam)
%
%   This method performs the operation specified by the OPTYPE and
%   INPUTPARAM. The OPTYPE must be either 1 or 2. The INPUTPARAM is
%   dependent on OPTYPE, if OPTYPE is 1 then INPUTPARAM must have NODEID
%   value, if OPTYPE is 2 then INPUTPARAM must have MACADDR value.
%
%   NODEID is specified as either scalar or vector. If it is scalar, the
%   value specifies the node ID. If it is vector ([NODEID INTERFACEID]),
%   the value specifies the node ID, NODEID along with the interface ID,
%   INTERFACEID.
%
%   MACADDR is a decimal vector with 6 elements, representing the 6 octets
%   of the MAC address in decimal format.
%
%   [MACADDR, ~] = hNodeInfo(1, NODEID) returns the MAC address for the
%   given node with ID, NODEID.
%
%   [~, NODEID] = hNodeInfo(2, MACADDR) returns the node ID for the given
%   MAC address, MACADDR.

%   Copyright 2021 The MathWorks, Inc.

% First byte of MAC address contains the information about MAC
% address type. All MAC addresses that are locally managed should
% set Bit-1 (second bit from LSB) of the first byte to 1. Set it to
% 0 to use globally unique (OUI enforced) MAC addresses. This
% function assigns MAC addresses that are locally administrated.
macAddrByte1 = 2;

% Assign default value to output variable
macAddr = [macAddrByte1 0 0 0 0 0];
nodeID = 0;

% Switch to an operation type that is selected
switch opType
    % Get MAC address from NodeID
    case 1
        nodeID = inputParam;
        if numel(nodeID) > 1
            nID = nodeID(1);
            interface = nodeID(2);
        else
            nID = nodeID;
            interface = 1;
        end

        % Generate a MAC address, use the 2nd byte for the node interface
        % and use ultimate and penultimate bytes for node ID.
        if nID == 65535 % Broadcast Node ID
            macAddr = [255 255 255 255 255 255];
        elseif nID > 0
            macAddr(2) = interface;
            macAddr(end-1) = floor(nID/250);
            macAddr(end) = rem(nID, 250);
        end
    case 2 % Get NodeID from MAC address
        macAddrHex = inputParam;
        macAddrDec = hex2dec((reshape(macAddrHex, 2, [])'))';
        % Node address is broadcast address
        if isequal(macAddrDec, [255 255 255 255 255 255])
            nodeID = 65535; % Broadcast Node ID
        else
            nodeID(1) = macAddrDec(end-1)*250 + macAddrDec(end);
            nodeID(2) = macAddrDec(2);
        end
end
