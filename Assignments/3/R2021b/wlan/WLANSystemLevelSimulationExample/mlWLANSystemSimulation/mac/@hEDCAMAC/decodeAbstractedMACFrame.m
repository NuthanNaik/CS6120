function [rxCfg, isValid] = decodeAbstractedMACFrame(edcaMAC, frame, subframeNum)
%decodeAbstractedMACFrame Decodes the given abstracted MAC frame
%
%   [RXCFG, ISVALID]= decodeAbstractedMACFrame(EDCAMAC, FRAME, SUBFRAMENUM)
%   decodes the given abstracted MAC frame.
%
%   RXCFG is a structure of type hEDCAMAC.EmptyMACConfig, indicates the MAC
%   frame configuration containing the decoded MAC parameters.
%
%   ISVALID is a boolean flag, indicates whether the received frame passed
%   the FCS check.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   FRAME is a structure of type hEDCAMAC.EmptyMACFrame, indicates the
%   abstracted MAC frame.
%
%   SUBFRAMENUM is an integer, indicates the number of subframe to be
%   decoded in an A-MPDU. For a non-aggregated frame, the value is 1.

%   Copyright 2021 The MathWorks, Inc.

% Initialize MAC frame configuration
rxCfg = edcaMAC.EmptyMACConfig;

isValid = frame.FCSPass(subframeNum, edcaMAC.UserIndexSU);

% Fill the received frame configuration, if received frame is valid
if(isValid)
    % Decoded frame configuration
    rxCfg.FrameType = frame.FrameType;
    rxCfg.FrameFormat = frame.FrameFormat;
    rxCfg.TID = frame.TID;
    rxCfg.Duration = frame.Duration;
    rxCfg.Address1 = frame.Address1;
    rxCfg.Address2 = frame.Address2;
    rxCfg.Address3 = frame.Address3(subframeNum, :, edcaMAC.UserIndexSU);
    rxCfg.SequenceNumber = frame.SequenceNumber(subframeNum, edcaMAC.UserIndexSU);
    rxCfg.Retransmission = frame.Retransmission(subframeNum, edcaMAC.UserIndexSU);
    rxCfg.AckPolicy = frame.AckPolicy;
    rxCfg.MPDUAggregation = frame.MPDUAggregation;
    
    if strcmp(rxCfg.FrameType, 'Block Ack')
        rxCfg.BlockAckBitmap = frame.BABitmap;
    end
end
end
