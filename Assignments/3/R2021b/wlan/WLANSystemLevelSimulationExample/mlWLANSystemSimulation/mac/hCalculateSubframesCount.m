function msduCount = hCalculateSubframesCount(msduLengths, queueLengths, acs, primaryAC, maxAggLen, heMUCfg, isFourAddressFrame)
%hCalculateSubframesCount Calculates the number of subframes required to
%form MU-PSDU
%
%   This is an example helper function.
%
% MSDUCOUNT = hCalculateSubframesCount(MSDULENGTHS, QUEUELENGTHS, ACS,
% PRIMARYAC, MAXAGGLEN, HEMUCFG, ISMESHFRAME) Returns the maximum number of
% MSDUs per user that can be used to form a MU-PSDU.
%
% MSDULENGTHS is an [N x 4 x M] array of doubles representing the lengths
% of buffered MSDUs in MAC for 4 ACs. Where N represents the size of the
% queue and M represents number of users in multi-user (MU) transmission.
%
% QUEUELENGTHS is an [M x 4] array of doubles representing the number of
% buffered frames in MAC for 4 ACs. Where M represents number of users in
% MU transmission.
%
% ACS is a column vector of doubles with M elements representing access
% category of the user in OFDMA transmission. Where M represents number of
% users in MU transmission.
%
% PRIMARYAC is a scalar double representing primary AC of the MU-PSDU
%
% MAXAGGLEN is the maximum number of subframes allowed in an A-MPDU
%
% HEMUCFG is physical layer configuration object for HE multi user format
%
% MSDUCOUNT is a column vector of doubles representing the maximum number
% of MSDUs that can be aggregated per user in an MU transmission
%
% ISFOURADDRESSFRAME is a flag indicating whether the frame is a 4-address
% format mesh data frame

%   Copyright 2021 The MathWorks, Inc.

% Number of users in MU PPDU
numUsers = numel(heMUCfg.User);
% Number of MSDUs dequeued for each user
msduCount = zeros(numUsers, 1);

% Symbol duration including guard interval (microseconds)
switch heMUCfg.GuardInterval
    case 0.8
        symbolTime = 13.6;
    case 1.6
        symbolTime = 14.4;
    otherwise % 3.2
        symbolTime = 16;
end

% Maximum allowed TXOP duration (microseconds)
maxTxopDuration = 5484;

% TXOP duration
txopDuration = maxTxopDuration;

% Maximum transmission time of the frames corresponding to primary AC
primaryACTxtimeMax = 0;

% A-MPDU subframe delimiter (4 Octets)
delimiterOverhead = 4;

% Get MSDUs count for each user
for userIdx = 1:numUsers
    % Maximum number of symbols can be transmitted in the TxOp
    numSymbols = floor(txopDuration/symbolTime);
    
    % Get NDBPS of the user
    if heMUCfg.STBC
        nss = 1;
    else
        nss = heMUCfg.User{userIdx}.NumSpaceTimeStreams;
    end
    rdp = wlan.internal.heRateDependentParameters(heMUCfg.RU{heMUCfg.User{userIdx}.RUNumber}.Size, ...
        heMUCfg.User{userIdx}.MCS,nss,heMUCfg.User{userIdx}.DCM);
    ndbps = rdp.NDBPS;
    
    % Maximum possible PSDU length for the user
    maxPSDULength = floor((numSymbols*ndbps)/8);
    % PSDU length of the user
    psduLength = 0;
    % MSDU index
    msduIdx = 0;
    % MPDU overhead
    if isFourAddressFrame(userIdx)
        % QoS Data MAC header, FCS, and Mesh control (36 Bytes)
        mpduOverhead = 36;
    else
        % QoS Data MAC header and FCS (30 Bytes)
        mpduOverhead = 30;
    end
    
    % Get MSDUs count based on queue availability and maximum possible PSDU
    % length
    while ((psduLength < maxPSDULength) && ...
            (queueLengths(userIdx, acs(userIdx)) > msduCount(userIdx)) && ...
            (maxAggLen > msduCount(userIdx)))
        msduIdx = msduIdx + 1;
        
        psduLength = psduLength + delimiterOverhead + mpduOverhead + msduLengths(userIdx, acs(userIdx), msduIdx);
        
        % Subframe padding overhead for aggregated frames
        subFramePadding = abs(mod(psduLength, -4));
        psduLength = psduLength + subFramePadding;
        
        if (psduLength < maxPSDULength)
            % Increment MSDU count
            msduCount(userIdx) = msduCount(userIdx)+1;
        else
            break;
        end
    end
    
    % For OFDMA, frames from all users should be aligned to the txtime of
    % primary AC.
    if (acs(userIdx) == primaryAC)
        % Consider txOpDuration as maximum allowed TxOp duration for
        % primary AC
        txopDuration = maxTxopDuration;
        primaryACTxtime = ceil(psduLength*8/ndbps) * symbolTime;
        % Update 'primaryACTxtimeMax' if required
        if (primaryACTxtimeMax < primaryACTxtime)
            primaryACTxtimeMax = primaryACTxtime;
        end
    else
        % Consider txopDuration as primaryACTxtimeMax for secondary ACs
        txopDuration = primaryACTxtimeMax;
    end
end
end
