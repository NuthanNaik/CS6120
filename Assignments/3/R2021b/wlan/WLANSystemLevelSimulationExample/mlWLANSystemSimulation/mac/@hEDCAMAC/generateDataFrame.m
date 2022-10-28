function frameToPHY = generateDataFrame(edcaMAC, retry, durationField, frameData, userIdx)
%generateDataframe Generates and returns a MAC data frame
%
%   FRAMETOPHY = generateDataframe(EDCAMAC, RETRY, DURATIONFIELD,
%   FRAMEDATA) generates and returns the data frame PSDU and its
%   information.
%
%   FRAMETOPHY is a structure of type hEDCAMAC.EmptyFrame, indicates
%   the MAC data frame passed to PHY transmitter.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   RETRY is boolean flag, indicates the retransmission value for the
%   frame.
%
%   DURATIONFIELD is an integer, indicates the estimated time (in micro
%   seconds) to transmit the frame(s).
%
%   FRAMEDATA is a structure indicates the transmission frame dequeued from
%   MAC queue.

%   Copyright 2021 The MathWorks, Inc.

tx = edcaMAC.Tx;

% User index for single user processing.
userIndexSU = edcaMAC.UserIndexSU;

% Initialize output frame
frameToPHY = edcaMAC.EmptyFrame;
frameToPHY.IsEmpty = false;
macFrame = edcaMAC.EmptyMACFrame;
macFrame.IsEmpty = false;

subframeBoundaries = zeros(edcaMAC.MaxSubframes, 2);

% Generate MAC frame
if ~edcaMAC.MPDUAggregation
    % Fill sub frames information. In case of MPDU consider it as single
    % subframe
    numMPDUs = 1;
    numSubframes = numMPDUs;
    subframeBoundaries(1, :) = [1, tx.TxPSDULength(userIdx)];
    
else % Aggregated frame of format HT, VHT, HE-SU, or HE-EXT-SU
    % Number of MPDUs being transmitted in the A-MPDU. Since there is no
    % MSDU aggregation (A-MSDU) each A-MPDU subframe consists only one
    % MSDU.
    numMPDUs = frameData.MSDUCount;
    numSubframes = numMPDUs;
    subframeStartIndex = 1;
    for idx = 1:numMPDUs
        subframeBoundaries(idx, 1) = subframeStartIndex;
        subframeBoundaries(idx, 2) = tx.TxMPDULengths(idx, userIdx);
        subframeStartIndex = subframeStartIndex + tx.TxSubframeLengths(idx, userIdx);
    end
end

retryList = repmat(retry, 1, numMPDUs);

frameFormat = hFrameFormats.getFrameFormatString(edcaMAC.TxFormat, 'MAC');

if edcaMAC.FrameAbstraction
    macFrame.FrameType = 'QoS Data';
    macFrame.FrameFormat = frameFormat;
    macFrame.Address1 = frameData.DestinationMACAddress;
    macFrame.Address2 = edcaMAC.MACAddress;
    isGroupAddr = hEDCAMAC.isGroupAddress(macFrame.Address1);
    if edcaMAC.DisableAck || isGroupAddr
        macFrame.AckPolicy = 'No Ack';
    else
        macFrame.AckPolicy = 'Normal Ack/Implicit Block Ack Request';
    end
    macFrame.FourAddressFrame(1:numMPDUs, userIndexSU) = frameData.FourAddressFrame(1:numMPDUs);
    for idx = 1:numMPDUs
        if macFrame.FourAddressFrame(idx, userIndexSU)
            macFrame.Address3(idx, :, userIndexSU) = frameData.MeshDestinationAddress(idx, :);
            macFrame.Address4(idx, :, userIndexSU) = frameData.MeshSourceAddress(idx, :);
        else
            if isGroupAddr
                macFrame.Address3(idx, :, userIndexSU) = frameData.MeshSourceAddress(idx, :);
            else
                macFrame.Address3(idx, :, userIndexSU) = edcaMAC.BSSID;
            end
        end
        macFrame.MeshSequenceNumber(idx, userIndexSU) = frameData.MeshSequenceNumber(idx);
        macFrame.FCSPass(idx, userIndexSU) = true;
        macFrame.DelimiterFails(idx, userIndexSU) = false;
    end
    macFrame.Duration = durationField;
    macFrame.TID = edcaMAC.AC2TID(frameData.AC+1);
    macFrame.SequenceNumber(1:numMPDUs) = tx.TxSequenceNumbers(1:numMPDUs);
    macFrame.Retransmission(1:numMPDUs) = retryList;
    macFrame.MPDUAggregation = edcaMAC.MPDUAggregation;
    macFrame.MPDULength = tx.TxMPDULengths(:, userIdx);
    macFrame.PSDULength(userIndexSU) = tx.TxPSDULength(userIdx);
    macFrame.PayloadLength(1:numMPDUs, userIndexSU) = frameData.MSDULength(1:numMPDUs);

    dataFrame = [];
else
    % Initialize address lists
    cfgMACAddr3List = repmat('0', numMPDUs, 12);
    cfgMACAddr4List = repmat('0', numMPDUs, 12);
    
    macFrame.IsEmpty = true;
    
    % Configure MAC configuration object to generate a full MAC frame
    cfgMAC = edcaMAC.EmptyMACConfig;
    cfgMAC.FrameType = 'QoS Data';
    cfgMAC.FrameFormat = frameFormat;
    if strcmp(frameFormat, 'HE-MU')
        % HE-MU format is not supported by MAC frame generator. So to generate
        % a HE-MU frame, individual HE-SU frames are generated first and then
        % adjusted for MU padding
        cfgMAC.FrameFormat = 'HE-SU';
    end
    cfgMAC.Retransmission = retry;
    cfgMAC.Duration = durationField;
    cfgMAC.Address1 = frameData.DestinationMACAddress;
    cfgMAC.Address2 = edcaMAC.MACAddress;
    isGroupAddr = hEDCAMAC.isGroupAddress(cfgMAC.Address1);
    for idx = 1:numMPDUs
        if frameData.FourAddressFrame(idx)
            cfgMACAddr3List(idx, :) = frameData.MeshDestinationAddress(idx, :);
            cfgMACAddr4List(idx, :) = frameData.MeshSourceAddress(idx, :);
        else
            if isGroupAddr
               cfgMACAddr3List(idx, :) = frameData.MeshSourceAddress(idx, :);
            else
               cfgMACAddr3List(idx, :) = edcaMAC.BSSID;
            end
        end
    end
    cfgMAC.TID = edcaMAC.AC2TID(frameData.AC+1);
    cfgMAC.MPDUAggregation = edcaMAC.MPDUAggregation;
    cfgMAC.SequenceNumber = tx.TxSequenceNumbers(1);
    
    if edcaMAC.DisableAck || isGroupAddr
        cfgMAC.AckPolicy = 'No Ack';
    else
        cfgMAC.AckPolicy = 'Normal Ack/Implicit Block Ack Request';
    end

    % Generate MAC frame
    if ~edcaMAC.MPDUAggregation
        msdu = double(frameData.Data(1, 1:frameData.MSDULength(1)))';
        dataFrameDec = wlan.internal.macGenerateMPDU(msdu, cfgMAC);
    else
        numMPDUs = frameData.MSDUCount;
        msduList = cell(numMPDUs, 1);

        % Prepare the MPDUs
        for i = 1:numMPDUs
            msduList{i} = double(frameData.Data(i, 1:frameData.MSDULength(i)))';
        end

        cfgMAC.MinimumMPDUStartSpacing = 0;
        cbwStr = hEDCAMAC.getChannelBandwidthStr(edcaMAC.AvailableBandwidth); % Channel bandwidth
        % Prepare the A-MPDU
        switch frameFormat
            case 'HT-Mixed'
                tx.CfgHT.AggregatedMPDU = edcaMAC.MPDUAggregation;
                tx.CfgHT.MCS = tx.TxMCS(userIndexSU);
                tx.CfgHT.ChannelBandwidth = cbwStr;
                tx.CfgHT.NumTransmitAntennas = edcaMAC.NumTxChains;
                tx.CfgHT.NumSpaceTimeStreams = edcaMAC.NumTxChains;
                [dataFrameDec, ~] = hAggregateMPDUs(cfgMAC, tx.CfgHT, msduList, ...
                    tx.TxSequenceNumbers(1:numMPDUs), retryList, cfgMACAddr3List, cfgMACAddr4List);

            case 'VHT'
                tx.CfgVHT.MCS = tx.TxMCS(userIndexSU);
                tx.CfgVHT.ChannelBandwidth = cbwStr;
                tx.CfgVHT.NumTransmitAntennas = edcaMAC.NumTxChains;
                tx.CfgVHT.NumSpaceTimeStreams = edcaMAC.NumTxChains;
                [dataFrameDec, ~] = hAggregateMPDUs(cfgMAC, tx.CfgVHT, msduList, ...
                    tx.TxSequenceNumbers(1:numMPDUs), retryList, cfgMACAddr3List, cfgMACAddr4List);

            otherwise % 'HE-SU', 'HE-EXT-SU'
                tx.CfgHE.MCS = tx.TxMCS(userIndexSU);
                tx.CfgHE.ChannelBandwidth = cbwStr;
                tx.CfgHE.ExtendedRange = (edcaMAC.TxFormat == hFrameFormats.HE_EXT_SU);
                tx.CfgHE.NumTransmitAntennas = edcaMAC.NumTxChains;
                tx.CfgHE.NumSpaceTimeStreams = edcaMAC.NumTxChains;
                [dataFrameDec, ~] = hAggregateMPDUs(cfgMAC, tx.CfgHE, msduList, ...
                    tx.TxSequenceNumbers(1:numMPDUs), retryList, cfgMACAddr3List, cfgMACAddr4List);
        end
    end

    % MAC frame bits
    dataFrame = zeros(numel(dataFrameDec)* 8, 1);
    bitIdx = 1;
    for decIdx = 1:numel(dataFrameDec)
        dataFrame(bitIdx:bitIdx+7) = bitget(dataFrameDec(decIdx), 1:8);
        bitIdx = decIdx*8 + 1;
    end
end

% Return output frame
frameToPHY.MACFrame = macFrame;
frameToPHY.Data(1:numel(dataFrame), userIndexSU) = dataFrame;
frameToPHY.PSDULength(userIndexSU) = tx.TxPSDULength(userIdx);
frameToPHY.Timestamp(1:numMPDUs, userIndexSU) = frameData.Timestamp(1:numMPDUs);
frameToPHY.SubframeBoundaries(:, :, userIndexSU) = subframeBoundaries;
frameToPHY.NumSubframes(userIndexSU) = numSubframes;
frameToPHY.SequenceNumbers(1:numMPDUs, userIndexSU) = tx.TxSequenceNumbers(1:numMPDUs);
end

function [ampdu, frameLength] = hAggregateMPDUs(cfgMAC, cfgPHY, msduList, ...
    sequenceNumberList, retryList, address3List, address4List)
%hAggregateMPDUs Generate A-MPDU
%
%   This is an example helper function.
%
%   [AMPDU, FRAMELENGTH] = hAggregateMPDUs(CFGMAC, CFGPHY, MSDULIST,
%   SEQUENCENUMBERLIST, RETRYLIST, ADDRESS3LIST, ADDRESS4LIST) generates an
%   A-MPDU, by creating and appending the MPDUs containing the MSDUs in the
%   MSDULIST.
%
%   AMPDU is the aggregated MPDU, returned as a column vector of decimal
%   octets.
%
%   FRAMELENGTH is the PSDU length for an HT format A-MPDU and APEP length
%   for a VHT or HE format A-MPDU, returned as the number of octets.
%
%   CFGMAC is an object of type <a href="matlab:help('wlanMACFrameConfig')">wlanMACFrameConfig</a>.
%
%   CFGPHY is an object of type <a href="matlab:help('wlanHTConfig')">wlanHTConfig</a>, <a href="matlab:help('wlanVHTConfig')">wlanVHTConfig</a>, or
%   <a href="matlab:help('wlanHESUConfig')">wlanHESUConfig</a>.
%
%   MSDULIST is the list of MSDUs, specified as a cell array where each
%   element is a vector of decimal octets.
%
%   SEQUENCENUMBERLIST is the list of sequence numbers corresponding to
%   MSDUs provided in the MSDULIST, specified as a column vector where each
%   element is in the range of [0 - 4095].
%
%   RETRYLIST is the list of retry flags corresponding to MSDUs provided in
%   the MSDULIST, specified as a logical column vector.
%
%   ADDRESS3LIST is the list of addresses to be filled in 'Address3' field
%   of MAC header corresponding to MSDUs provided in the MSDULIST and
%   specified as character vector of size M x 12 where M is the number of
%   MSDUs. For non mesh frames, Address3 represents BSSID or source
%   address. For mesh frames, Address3 represents mesh destination address.
%
%   ADDRESS4LIST is the list of addresses to be filled in 'Address4' field
%   of MAC header corresponding to MSDUs provided in the MSDULIST and
%   specified as character vector of size M x 12 where M is the number of
%   MSDUs. This is applicable only for mesh frames and represents mesh
%   source address.

    numMPDUs = numel(msduList);
    mpduList = cell(1, numMPDUs);

    switch class(cfgPHY)
        case 'wlanNonHTConfig'
            error('Aggregation of Non-HT frames is not supported');

        case 'wlanHTConfig'
            cfgMAC.FrameFormat = 'HT-Mixed';

        case 'wlanVHTConfig'
            cfgMAC.FrameFormat = 'VHT';

        case 'wlanHESUConfig'
            cfgMAC.FrameFormat = 'HE-SU';
    end

    for i = 1:numMPDUs
        cfgMAC.SequenceNumber = sequenceNumberList(i);
        cfgMAC.Retransmission = retryList(i);
        cfgMAC.Address3 = address3List(i, :);
        % Fill Address4, ToDS and FromDS fields for mesh subframes
        if ~strcmp('000000000000', address4List(i, :))
            cfgMAC.Address4 = address4List(i, :);
            cfgMAC.ToDS = 1;
            cfgMAC.FromDS = 1;
        end
        mpduList{i} = wlan.internal.macGenerateMPDU(msduList{i}, cfgMAC);
    end

    [ampdu, frameLength] = wlan.internal.macGenerateAMPDU(mpduList, cfgMAC, cfgPHY);

end
