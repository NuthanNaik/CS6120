classdef hTGaxLinkQualityModel < handle
%hTGaxLinkQualityModel Create a link quality model object
%   abstraction = hTGaxLinkQualityModel returns a TGax link quality model.
%   This model is used to estimate the SINR for an 802.11ax single-user
%   link assuming perfect synchronization.
%
%   hTGaxLinkQualityModel methods:
%
%   estimateLinkQuality - returns the expected SINR per subcarrier.
%
%   See also hCalculateSINR.

%   Copyright 2021 The MathWorks, Inc.

%#codegen

    properties
        ChannelManager;
        NoiseFigure = 7; % Noise figure in dB
        SubcarrierSubsampling = 1; % Factor to subsample active subcarriers
    end

    methods
        function obj = hTGaxLinkQualityModel(cm)
            obj.ChannelManager = cm;
        end

        function SINR = estimateLinkQuality(obj, cfgSet, fieldSet, varargin)
            %channelAbstraction Calculate the SINR per subcarrier and
            % spatial stream given the signal of interest and interferers

            if nargin==5
                % SINR = estimateLinkQuality(obj, cfgSet, fieldSet, infoSet, rxIdx)
                infoSet = varargin{1};
                txIdxSet = infoSet(:,1);
                rxPowerSet = infoSet(:,2);
                rxIdx = varargin{2};
            else
                % SINR = estimateLinkQuality(obj, cfgSet, fieldSet, rxPowerSet, txIdxSet, rxIdx, ruIdx)
                rxPowerSet = varargin{1};
                txIdxSet = varargin{2};
                rxIdx = varargin{3};
                if nargin>6
                    ruIdx_soi = varargin{4};
                end
            end

            if iscell(cfgSet)
                cfg_soi = cfgSet{1};
            else
                cfg_soi = cfgSet(1);
            end
            numCfgSet = numel(cfgSet);

            % Number of interfering signals
            numInterferers = numel(txIdxSet)-1;
            assert(any(numCfgSet==[1 numInterferers+1]),'Must be one configuration per transmission or only a single configuration')

            txIdx_soi = txIdxSet(1); % Index of transmitter of interest
            Ptxrx_soi = rxPowerSet(1); % Receive power of transmitter of interest

            if ischar(fieldSet)
                field_soi = fieldSet;
            else
                if iscell(fieldSet)
                    field_soi = fieldSet{1};
                else
                    field_soi = fieldSet(1); % String array
                end
                assert(numCfgSet==numel(fieldSet),'Same number of configurations and fields must be provided')
            end

            % OFDM information of receiver processing - FFT length, number
            % of active tones and scalar for active to total number of
            % subcarriers
            isOFDMA = isa(cfg_soi,'wlanHEMUConfig');
            if isOFDMA && any(strcmp(field_soi,'data'))
                rxOFDMInfo = getOFDMInfo(cfg_soi, field_soi, ruIdx_soi);
            else
                rxOFDMInfo = getOFDMInfo(cfg_soi, field_soi);
            end

            % Noise power at receiver in a subcarrier
            fs = rxOFDMInfo.SampleRate;
            NF = obj.NoiseFigure;         % Noise figure (dB)
            T = 290;                      % Ambient temperature (K)
            BW = fs/rxOFDMInfo.FFTLength; % Bandwidth per subcarrier (Hz)
            k = 1.3806504e-23;            % Boltzmann constant (J/K)
            N0 = k*T*BW*10^(NF/10);       % Noise power per subcarrier (Watts)

            % Get channel matrix and precoding matrix for signal of interest
            Htxrx_soi = getChannelMatrix(obj.ChannelManager, rxOFDMInfo, txIdx_soi, rxIdx, obj.SubcarrierSubsampling);
            assert(cfg_soi.NumTransmitAntennas==size(Htxrx_soi,2),'Number of transmit antennas must match')
            if isOFDMA
                Wtx_soi = hGetPrecodingMatrix(cfg_soi, ruIdx_soi, field_soi, rxOFDMInfo, obj.SubcarrierSubsampling);
            else
                Wtx_soi = hGetPrecodingMatrix(cfg_soi, field_soi, rxOFDMInfo, obj.SubcarrierSubsampling);
            end
            HW_soi = calculateHW(Htxrx_soi,Wtx_soi);

            % Get number of 20 MHz subchannels and determine whether they
            % should be combined
            Nsc = rxOFDMInfo.NumSubchannels;
            combineSC = Nsc>1 && (any(strcmp(field_soi,'preamble')) || isa(cfg_soi,'wlanNonHTConfig'));

            % Combine subchannels for channel of interest if same data
            % transmitted on multiple subchannels
            if combineSC
                HW_soi = wlan.internal.mergeSubchannels(HW_soi, Nsc);
            end

            % This indicates interference is present. Since first one is signal of interest
            if numInterferers > 0
                HW_int = cell(numInterferers, 1);
                Ptxrx_int = zeros(numInterferers, 1);
                for i = 1:numInterferers
                    % Get channel matrix for interferer
                    txIntIdx = txIdxSet(i+1); % Skip the first value as it corresponds to signal of interest
                                        
                    % Get channel matrix for interferer (OFDM info based on signal of interest)
                    Hi = getChannelMatrix(obj.ChannelManager, rxOFDMInfo, txIntIdx, rxIdx, obj.SubcarrierSubsampling);
                    
                    % If only single transmission configuration and field passed assume it is the same for all interferers
                    setIdx = mod((i+1)-1,numCfgSet)+1;

                    % Get precoding matrix for interferer
                    if setIdx==1
                        % Assume same precoding used as signal of interest and already combined if required
                        Wi = Wtx_soi;
                    else
                        % Get precoding from interferer using signal of interest OFDM configuration 
                        [cfgInt,fieldInt] = getInterfererConfig(setIdx, cfgSet, fieldSet);
                        if isOFDMA
                            Wi = hGetPrecodingMatrix(cfgInt, fieldInt, cfg_soi, ruIdx_soi, field_soi, obj.SubcarrierSubsampling);
                        else
                            Wi = hGetPrecodingMatrix(cfgInt, fieldInt, cfg_soi, field_soi, obj.SubcarrierSubsampling);
                        end
                    end
                    HWi = calculateHWInt(Hi,Wi);
                    % Combine subchannels for channel of interest if same
                    % data transmitted on multiple subchannels
                    if combineSC
                        HWi = wlan.internal.mergeSubchannels(HWi, Nsc);
                    end
                    HW_int{i} = HWi;
                    
                    Ptxrx_int(i) = rxPowerSet(i+1); % Skip the first value as it corresponds to signal of interest
                end
                SINR = hCalculateSINR(HW_soi, Ptxrx_soi, N0, HW_int, Ptxrx_int);
            else
                % No interference
                SINR = hCalculateSINR(HW_soi, Ptxrx_soi, N0);
            end
        end
    end
end

function [cfgInt,fieldInt] = getInterfererConfig(setIdx,cfgSet,fieldSet)
    % If only single transmission configuration and field passed assume it
    % is the same for all interferers

    if iscell(cfgSet)
        cfgInt = cfgSet{setIdx};
    elseif isvector(cfgSet)
        cfgInt = cfgSet(setIdx);
    else
        cfgInt = cfgSet;
    end
    if iscell(fieldSet)
        fieldInt = fieldSet{setIdx};
    elseif isstring(fieldSet)
        fieldInt = fieldSet(setIdx);
    else
        % Char array, assume same field for interferer as field of interest
        fieldInt = fieldSet;
    end
end

function ofdmInfo = getOFDMInfo(cfg,field,ruIndx)
   switch field
       case 'data'
           % Get OFDM info for data fields of formats
            switch class(cfg)
                case 'wlanHEMUConfig'
                    ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg,ruIndx);
                case {'wlanHESUConfig','wlanHETBConfig'}
                    ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg);
                case 'wlanVHTConfig'
                    ofdmInfo = wlanVHTOFDMInfo('VHT-Data',cfg);
                case 'wlanHTConfig'
                    ofdmInfo = wlanHTOFDMInfo('HT-Data',cfg);
                case 'wlanNonHTConfig'
                    ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg);
                otherwise
                    error('Unexpected format');
            end
       case 'preamble'
           % Get OFDM info for preamble fields of formats
            switch class(cfg)
                case {'wlanHESUConfig','wlanHETBConfig','wlanHEMUConfig'}
                    ofdmInfo = wlanHEOFDMInfo('HE-SIG-A',cfg);
                case 'wlanVHTConfig'
                    ofdmInfo = wlanVHTOFDMInfo('VHT-SIG-A',cfg);
                case 'wlanHTConfig'
                    ofdmInfo = wlanHTOFDMInfo('HT-SIG',cfg);
                case 'wlanNonHTConfig'
                    ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg);
                otherwise
                    error('Unexpected format');
            end
       otherwise
           error('Unexpected field')
   end
   ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
end

function HW = calculateHW(H,W)
    % Calculate HWtxrx, which include channel and precoding response for
    % channel of interest
    [Nst,~,Nr] = size(H);
    Nsts = size(W,2);
    WP = permute(W,[1 3 2]); % Nst-by-Nt-by-Nsts
    HW = coder.nullcopy(complex(zeros(Nst,Nr,Nsts)));
    for i = 1:Nr
        for j = 1:Nsts
            HW(:,i,j) = sum(H(:,:,i).*WP(:,:,j),2);
        end
    end
    HW = permute(HW,[1 3 2]); % Permute to Nsts-by-Nsts-by-Nr
end

function HW_int = calculateHWInt(Htxrx_int,Wtx_int)
    % Combine channel and precoding matrix into an effective channel matrix

    % Check sizes are compatible for each precoding and channel
    % matrix and with the channel of interest
    [Nst_hi,Nt_hi,Nr_hi] = size(Htxrx_int);
    
    if ~iscell(Wtx_int)
        [Nst_wi,~,Nt_wi] = size(Wtx_int);
        assert(all([Nst_hi Nt_hi]==[Nst_wi Nt_wi]),'Mismatch in precoding and channel matrix dimensions for interferer')
    else
        Nstint = 0;
        for ir = 1:numel(Wtx_int)
            [Nstintt,~,Ntxintt] = size(Wtx_int{ir});
            Nstint = Nstint+Nstintt;
            assert(all(Nt_hi==Ntxintt),'Mismatch in precoding and channel matrix dimensions for interfere')
        end
        % Sum of subcarriers for all RUs must equal sum in channel
        assert(Nst_hi==Nstint,'Mismatch in precoding and channel matrix dimensions for interferer')
    end

    % Permute for efficiency Wtx to Nst-Nt-by-Nsts
    if ~iscell(Wtx_int)
        Wtx_intT = permute(Wtx_int,[1 3 2]);
    else
        % The number of streams are different per subcarrier (OFDMA)
        Wtx_intT = cell(1,numel(Wtx_int));
        for ir = 1:numel(Wtx_int)
            Wtx_intT{ir} = permute(Wtx_int{ir},[1 3 2]);
        end
    end

    % Calculate H*W for interferers as a vector calculation
    if ~iscell(Wtx_intT)
        Wint = Wtx_intT; % Nst-by-Nt-by-Nsts
        Hi = Htxrx_int; % Nst-by-Nt-by-Nr
        NstsInt = size(Wint,3);
        HW_k = coder.nullcopy(complex(zeros(Nst_hi,Nr_hi,NstsInt)));
        for i = 1:Nr_hi
            for j = 1:NstsInt
                HW_k(:,i,j) = sum(Hi(:,:,i).*Wint(:,:,j),2);
            end
        end
        HW_int= permute(HW_k,[1 3 2]); % Nst-by-Nsts-by-Nr
    else
        % The number of streams are different per subcarrier (OFDMA)
        Wint = Wtx_intT; % Cell of Nst-by-Nt-by-Nsts
        Hi = Htxrx_int; % Nst-by-Nt-by-Nr
        offset = 0;

        % Create array for up to the maximum number of space-time streams
        % in the interfering transmission. Unused STS for a subcarrier will
        % be zero.
        NstsInt = cellfun(@(x)size(x,3),Wint);
        NstsIntMax = max(NstsInt);
        HW_int = complex(zeros(Nst_hi,NstsIntMax,Nr_hi));

        for ir = 1:numel(Wint)
            NstInt = size(Wint{ir},1);
            HW_k_ir = coder.nullcopy(complex(zeros(NstInt,Nr_hi,NstsInt(ir))));
            HiIdx = offset + (1:NstInt);
            for i = 1:Nr_hi
                for j = 1:NstsInt(ir)
                    HW_k_ir(:,i,j) = sum(Hi(HiIdx,:,i).*Wint{ir}(:,:,j),2);
                end
            end
            offset = offset+NstInt;

            HW_int(HiIdx,1:NstsInt(ir),:) = permute(HW_k_ir,[1 3 2]); % Nst-by-Nsts-by-Nr
        end
    end
end