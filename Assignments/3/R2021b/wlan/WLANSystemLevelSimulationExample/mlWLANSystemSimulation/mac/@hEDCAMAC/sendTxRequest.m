function macReqToPHY = sendTxRequest(edcaMAC, requestType, varargin)
%sendTxRequest Generates either Tx start request along with PHY waveform
% configuration or Tx end request
%   MACREQTOPHY = sendTxRequest(EDCAMAC, "Start", CBW, FORMAT, MCS, LENGTH)
%   generates Tx start request that is to be sent to PHY layer.
%
%   MACREQTOPHY represents either Tx start or Tx end request from MAC to
%   PHY
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   CBW is the channel bandwidth specified as one of 20, 40, 80, or 160.
%
%   FORMAT is enumerated value of physical layer format of frame.
%
%   MCS is a vector of size M x 1, where M is the maximum number of users
%   supported in Multi-User(MU) transmission. The value of M can be 9, 18,
%   37, or 74 corresponding to bandwidths 20, 40, 80, 160. First element
%   specifies MCS index of frame for which transmission start request is
%   being generated. Remaining elements are filled with zeros for single
%   user support.
%
%   LENGTH is a vector of size M x 1, where M is the maximum number of
%   users supported in Multi-User(MU) transmission. The value of M can be
%   9, 18, 37, or 74 corresponding to bandwidths 20, 40, 80, 160. First
%   element specifies length of frame for which transmission start request
%   is being generated. Remaining elements are filled with zeros for single
%   user support.
%
%   MACREQTOPHY = sendTxRequest(EDCAMAC, "End") generates Tx end request
%   that is to be sent to PHY layer.

%   Copyright 2021 The MathWorks, Inc.

macReqToPHY = edcaMAC.EmptyPHYIndication;
if strcmp(requestType, "Start")
    cbw = varargin{1};
    frameFormat = varargin{2};
    mcsIndex = varargin{3};
    psduLength = varargin{4};
    if frameFormat == hFrameFormats.NonHT
        mpduAggregation = false;
    elseif frameFormat == hFrameFormats.HTMixed
        mpduAggregation = edcaMAC.MPDUAggregation;
    else % VHT/HE
        mpduAggregation = true;
    end
    
    % Fill Tx vector parameters
    macReqToPHY.IsEmpty = false;
    macReqToPHY.MessageType = hPHYPrimitives.TxStartRequest;
    macReqToPHY.FrameFormat = frameFormat;
    macReqToPHY.MCSIndex = mcsIndex;
    macReqToPHY.PSDULength = psduLength;
    macReqToPHY.ChannelBandwidth = cbw;
    macReqToPHY.AggregatedMPDU = mpduAggregation;
    macReqToPHY.NumTransmitAntennas = edcaMAC.NumTxChains;
    macReqToPHY.NumSpaceTimeStreams = edcaMAC.NumTxChains;
    macReqToPHY.AllocationIndex = edcaMAC.Tx.AllocationIndex;
    macReqToPHY.StationIDs = edcaMAC.Tx.TxStationIDs;
    % Fill signal transmission power
    controlInfo = edcaMAC.PowerControl.ControlInfo;
    for userIdx = 1:edcaMAC.NumTxUsers
        controlInfo.MCSIndex = mcsIndex(userIdx);
        controlInfo.Bandwidth = cbw;
        macReqToPHY.TxPower(userIdx) = getTxPower(edcaMAC.PowerControl, controlInfo);
    end
    % Fill spatial reuse parameters
    macReqToPHY.EnableSROperation = edcaMAC.EnableSROperation;
    macReqToPHY.BSSColor = edcaMAC.BSSColor;
    macReqToPHY.LimitTxPower = edcaMAC.LimitTxPower;
    macReqToPHY.OBSSPDThreshold = edcaMAC.UpdatedOBSSPDThreshold;
    
else % strcmp(requestType, "End")
    macReqToPHY.IsEmpty = false;
    macReqToPHY.MessageType = hPHYPrimitives.TxEndRequest;  
end

end
