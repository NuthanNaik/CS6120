function W = hGetPrecodingMatrix(cfg,varargin)
%hGetPrecodingMatrix(CFGHE) return the precoding matrix
%
%   W = hGetPrecodingMatrix(CFG) returns the precoding matrix per
%   subcarrier W given the format configuration object CFG. The precoding
%   matrix is scaled such that sum(abs(W).^2) = 1, as in a typical WLAN
%   system, the power per subcarrier is normalized so the total power of
%   the transmission is 1 (0 dBW).
%
%   W is a Nst-by-Nsts-by-Ntx precoding matrix, where Nst is the number of
%   active subcarriers, Nsts is the number of space-time streams, and Ntx
%   is the number of transmit antennas.
%
%   CFG is the format configuration object of type <a href="matlab:help('wlanVHTConfig')">wlanVHTConfig</a>,
%   <a href="matlab:help('wlanHTConfig')">wlanHTConfig</a>, <a
%   href="matlab:help('wlanNonHTConfig')">wlanNonHTConfig</a>, <a
%   href="matlab:help('wlanS1GConfig')">wlanS1GConfig</a>, 
%   <a href="matlab:help('wlanHESUConfig')">wlanHESUConfig</a>, or <a href="matlab:help('wlanHETBConfig')">wlanHETBConfig</a>.
%
%   W = hGetPrecodingMatrix(CFGHE,FIELD) returns the precoding used for the
%   field. FIELD can be 'data' or 'preamble'.
%
%   W = hGetPrecodingMatrix(CFGHE,FIELD,CFGOFDM) returns the precoding
%   given the OFDM configuration defined by the structure CFGOFDM.
%   CFGOFDM is a strcuture with the following fields:
%     FFTLength              - The FFT length
%     CPLength               - The cyclic prefix length
%     NumTones               - The number of active subcarriers
%     ActiveFrequencyIndices - Indices of active subcarriers relative to DC
%                              in the range [-NFFT/2, NFFT/2-1]
%     ActiveFFTIndices       - Indices of active subcarriers within the FFT
%                              in the range [1, NFFT]
%
%   W = hGetPrecodingMatrix(CFG,FIELD,[CFGOFDM],CFGREF,[RUIDXREF],FIELDREF)
%   returns the precoding specified in CFG and FIELD but for subcarriers
%   defined by CFGREF and FIELDREF. When CFGREF is of type <a
%   href="matlab:help('wlanHEMUConfig')">wlanHEMUConfig</a> RUIDXREF is the
%   RU index. When CFG is of type <a
%   href="matlab:help('wlanHEMUConfig')">wlanHEMUConfig</a> W is a cell
%   array, were each element contains the precoding matrix for an RU which
%   overlaps the reference OFDM subcarrier configuration.
%
%   W = hGetPrecodingMatrix(CFGHEMU,RUIDX,parms.Field) returns the precoding for
%   the RU specified by RUIDX.
%
%   W = hGetPrecodingMatrix(...,SSFACTOR) returns the precoding with
%   subcarriers subsampled SSFACTOR times.

%   Copyright 2021 The MathWorks, Inc.

%#codegen

parms = parseInputs(cfg,varargin{:});

isOFDMA = strcmp(class(cfg),'wlanHEMUConfig'); %#ok<*STISA>
isDataField = strcmp(parms.Field,'data');

if isOFDMA && isDataField && parms.RUIndex==-1 
    % Extract the precoding from all RUs in a wlanHEMUConfig at subcarriers
    % specified by the reference configuration. Return a cell array where
    % each element corresponds to the overlapping subcarriers from an RU
    W = getOFDMAPrecodingMatrix(cfg,'data',parms.cfgRef,parms.FieldRef,parms.RUIndexRef,parms.SubsampleFactor);
    return
end
    
% Get the cyclic shift applied per OFDM symbol and space-time stream or transmit antenna
[Wcs,ofdmInfo,activeSCInd] = getCyclicShiftMatrix(cfg,parms);

if isDataField && ~isa(cfg,'wlanNonHTConfig')
    % Apply gamma rotation per 20 MHz for formats other than HE
    if any(strcmp(class(cfg),{'wlanVHTConfig','wlanHTConfig','wlanNonHTConfig'}))
        gamma = wlan.internal.vhtCarrierRotations(cfg.ChannelBandwidth);
        Wcs = Wcs.*gamma(ofdmInfo.ActiveFFTIndices,:,:);
    end

    % Spatial mapping only relevant for:
    % * Data field, as not supporting BeamChange=false
    % * Configurations which perform spatial mapping
    Wsm = getSpatialMappingMatrix(cfg,parms.RUIndex,ofdmInfo,activeSCInd);
    W = Wsm.*Wcs; % Nst-by-Nsts-by-Ntx
    
    if isOFDMA
        % wlanHEMUConfig
        % The transmit power is normalized by the number of space-time streams, RU size etc.
        allocInfo = ruInfo(cfg);
        numSTS = allocInfo.NumSpaceTimeStreamsPerRU;
        alpha = allocInfo.PowerBoostFactorPerRU;
        ruSize = allocInfo.RUSizes;
        ruScalingFactor = alpha(parms.RUIndex)/sqrt(numSTS(parms.RUIndex));
        allScalingFactor = sqrt(sum(ruSize))/sqrt(sum(alpha.^2.*ruSize));
        W = W*allScalingFactor*ruScalingFactor;
    else
        % The transmit power is normalized by the number of space-time
        % streams. To make things easier perform this normalization in the
        % precoder. The normalization by number of transmit antennas is
        % done as part of the spatial mapping matrix calculation.
        W = W/sqrt(cfg.NumSpaceTimeStreams);
    end
else
    % Precoding includes per 20-MHz subchannel rotation
    % For all formats same pre-HE rotation applied
    [gamma,punc] = wlan.internal.hePreHECarrierRotations(cfg);
    W = Wcs.*gamma(ofdmInfo.ActiveFFTIndices,:,:);
    
    % Normalize for punctured subchannels as per IEEE P802.11ax/D7.0, Equation 27-5
    puncNorm = sum(~punc)/numel(punc);
    W = W/sqrt(puncNorm);

    % The transmit power is normalized by the number of transmit antennas.
    % To make things easier perform this normalization in the precoder. For
    % other formats this is performed in spatial mapping - but there is no
    % spatial mapping for non-HT or preambles.
    W = W/sqrt(cfg.NumTransmitAntennas);
end

% Scale precoding matrix to reflect actual power per subcarrier
if isOFDMA && isDataField
    numTonesTotal = sum(ruInfo(cfg).RUSizes);
else
    numTonesTotal = ofdmInfo.NumTones; % All returned subcarriers are active
end
if parms.DiffOFDMRef
    % If the subcarrier spacing is different between reference and signal
    % of interest then adjust the power per subcarrier from the signal of
    % interest. For example if there are 4x as many subcarriers in the
    % reference OFDM config, we expect the power on each to be 1/4 of the
    % power on 1 signal of interest subcarrier.
    scsDiff = getOFDMInfo(parms.cfgRef,parms.FieldRef,parms.RUIndexRef).FFTLength/ofdmInfo.FFTLength;
    W = W/sqrt(scsDiff*numTonesTotal);
else
    W = W/sqrt(numTonesTotal);
end

end

function parms = parseInputs(cfg,varargin)
    
    % Defaults
    ruIdx = -1;
    cfgRef = [];
    ruIdxRef = 1;
    fieldRef = 'data';
    ssFactor = 1; % Subsample factor
    isMUFOI = false;
    isMURef = false;
    ofdmCfg = [];
    
    validateField = true;
    useRefCfg = false;
    
    switch nargin
        case 1
            % W = hGetPrecodingMatrix(CFG)
            field = 'data';
        case 2
            if isnumeric(varargin{1})
                % W = hGetPrecodingMatrix(CFG,RUIDX)
                isMUFOI = true;
                ruIdx = varargin{1};
                field = 'data';
                validateField = false;
            else
                % W = hGetPrecodingMatrix(CFG,FIELD)
                field = varargin{1};
            end
        case 3
            if isnumeric(varargin{1})
                % W = hGetPrecodingMatrix(CFG,RUIDX,FIELD)
                isMUFOI = true;
                ruIdx = varargin{1};
                if isnumeric(varargin{2})
                    field = 'data';
                    validateField = false;
                else
                    field = varargin{2};
                end
            else
                if isnumeric(varargin{2})
                    % W = hGetPrecodingMatrix(CFG,FIELD,SSFACTOR)
                    field = varargin{1};
                    ssFactor = varargin{2};
                else
                    % W = hGetPrecodingMatrix(CFG,FIELD,OFDMCFG)
                    field = varargin{1};
                    ofdmCfg = varargin{2};
                    useRefCfg = true;
                end
            end
        case 4
            if isnumeric(varargin{1})
                if isnumeric(varargin{3})
                    % W = hGetPrecodingMatrix(CFG,RUIDX,FIELD,SSFACTOR)
                    isMUFOI = true;
                    ruIdx = varargin{1};
                    field = varargin{2};
                    ssFactor = varargin{3};
                else
                    % W = hGetPrecodingMatrix(CFG,RUIDX,FIELD,OFDMCFG)
                    isMUFOI = true;
                    ruIdx = varargin{1};
                    field = varargin{2};
                    ofdmCfg = varargin{3};
                end
            else
                if ~isstruct(varargin{2})
                    % W = hGetPrecodingMatrix(CFG,FIELD,CFGREF,FIELDREF)
                    field = varargin{1};
                    cfgRef = varargin{2};
                    fieldRef = varargin{3};
                    useRefCfg = true;
                else
                    % W = hGetPrecodingMatrix(CFG,FIELD,OFDMCFG,SSFACTOR)
                    field = varargin{1};
                    ofdmCfg = varargin{2};
                    ssFactor = varargin{3};
                end
            end
        case 5
            if isnumeric(varargin{1})
                % W = hGetPrecodingMatrix(CFG,RUIDX,FIELD,OFDMCFG,SSFACTOR)
                isMUFOI = true;
                ruIdx = varargin{1};
                field = varargin{2};
                ofdmCfg = varargin{3};
                ssFactor = varargin{4};
            else
                if isnumeric(varargin{3})
                    % W = hGetPrecodingMatrix(CFG,FIELD,CFGREF,RUIDXREF,FIELDREF)
                    isMURef = true;
                    ruIdxRef = varargin{3};
                    fieldRef = varargin{4};
                else
                    % W = hGetPrecodingMatrix(CFG,FIELD,CFGREF,FIELDREF,SSFACTOR)
                    fieldRef = varargin{3};
                    ssFactor = varargin{4};
                end
                field = varargin{1};
                cfgRef = varargin{2};
                useRefCfg = true;
            end
        case 6
            if isstruct(varargin{2})
                if isnumeric(varargin{4})
                    % W = hGetPrecodingMatrix(CFG,FIELD,OFDMCFG,CFGREF,RUIDXREF,FIELDREF)
                    isMURef = true;
                    ruIdxRef = varargin{4};
                    fieldRef = varargin{5};
                else
                    % W = hGetPrecodingMatrix(CFG,FIELD,OFDMCFG,CFGREF,FIELDREF,SSFACTOR)
                    fieldRef = varargin{4};
                    ssFactor = varargin{5};
                end
                field = varargin{1};
                ofdmCfg = varargin{2};
                cfgRef = varargin{3};
                useRefCfg = true;
            else
                if isnumeric(varargin{1})
                    % W = hGetPrecodingMatrix(CFGMU,RUIDX,FIELD,CFGREF,RUIDXREF,FIELDREF)
                    isMUFOI = true;
                    ruIdx = varargin{1};
                    field = varargin{2};
                    cfgRef = varargin{3};
                    ruIdxRef = varargin{4};
                    fieldRef = varargin{5};
                else
                    % W = hGetPrecodingMatrix(CFG,FIELD,CFGREF,RUIDXREF,FIELDREF,SSFACTOR)
                    field = varargin{1};
                    cfgRef = varargin{2};
                    ruIdxRef = varargin{3};
                    fieldRef = varargin{4};
                    ssFactor = varargin{5};
                end
                isMURef = true;
                useRefCfg = true;
            end
        case 7
            if isstruct(varargin{2})
                if isnumeric(varargin{1})
                    % W = hGetPrecodingMatrix(CFGMU,RUIDX,FIELD,OFDMCFG,CFGREF,RUIDXREF,FIELDREF)
                    isMUFOI = true;
                    ruIdx = varargin{1};
                    field = varargin{3};
                    cfgRef = varargin{4};
                    ruIdxRef = varargin{5};
                    fieldRef = varargin{6};
                else
                    % W = hGetPrecodingMatrix(CFG,FIELD,OFDMCFG,CFGREF,RUIDXREF,FIELDREF,SSFACTOR)
                    field = varargin{1};
                    cfgRef = varargin{3};
                    ruIdxRef = varargin{4};
                    fieldRef = varargin{5};
                    ssFactor = varargin{6};
                end
                ofdmCfg = varargin{2};
                isMURef = true;
                useRefCfg = true;
            else
                % W = hGetPrecodingMatrix(CFGMU,RUIDX,FIELD,CFGREF,RUIDXREF,FIELDREF,SSFACTOR)
                isMUFOI = true;
                isMURef = true;
                ruIdx = varargin{1};
                field = varargin{2};
                cfgRef = varargin{3};
                ruIdxRef = varargin{4};
                fieldRef = varargin{5};
                ssFactor = varargin{6};
                useRefCfg = true;
            end
        case 8
            % W = hGetPrecodingMatrix(CFGMU,RUIDX,FIELD,OFDMCFG,CFGREF,RUIDXREF,FIELDREF,SSFACTOR)
            isMUFOI = true;
            isMURef = true;
            ruIdx = varargin{1};
            field = varargin{2};
            ofdmCfg = varargin{3};
            cfgRef = varargin{4};
            ruIdxRef = varargin{5};
            fieldRef = varargin{6};
            ssFactor = varargin{7};
            useRefCfg = true;
    end
        
    if validateField && ~any(strcmp(field,{'data','preamble'}))
        error('Expect field to be data or preamble, %s provided',field);
    end
    
    if useRefCfg && isa(cfg,'wlanHEMUConfig')
        % If a refererence configuration is passed then the 
        isMUFOI = true;
    end
    
    % If field or waveform format for reference differ from
    % receiver then extract appropriate subcarriers
    diffOFDMRef = useRefCfg && ...
        (~strcmp(field,fieldRef) || ...           % Fields are different
        ~strcmp(class(cfgRef),class(cfg)) || ...  % Configurations are different
        (strcmp(class(cfgRef),class(cfg)) && isa(cfg,'wlanHETBConfig')) || ... % HE-TB 
        (strcmp(class(cfgRef),class(cfg))) && isMUFOI && ((ruIdx~=ruIdxRef) || ~isequal(cfg.AllocationIndex,cfgRef.AllocationIndex))); % OFDMA allocations are different or RU indices are different

    parms = struct;
    parms.Field = field;
    parms.RUIndex = ruIdx;
    parms.cfgRef = cfgRef;
    parms.RUIndexRef = ruIdxRef;
    parms.FieldRef = fieldRef;
    parms.SubsampleFactor = ssFactor;
    parms.DiffOFDMRef = diffOFDMRef;
    parms.cfgOFDM = ofdmCfg;
    parms.isMUFOI = isMUFOI;
    parms.isMURef = isMURef;
end

function [csd,ofdmInfo,activeSCInd] = getCyclicShiftMatrix(cfg,parms)
% CSD = getCyclicShiftMatrix returns a Nst-by-Nsts-by-1/Ntx matrix
% containing the cyclic shift applied to each subcarrier and space-time
% stream in the Data filed. Nst is the number of active subcarriers and
% Nsts is the number of space-time streams. If the cyclic shift applied to
% each transmitter is the same the size of third dimension returned is 1.

if parms.DiffOFDMRef || isempty(parms.cfgOFDM)
    % Get OFDM info for OFDM config of field of interest if OFDM config not
    % provided or the OFDM config for the signal of interest is different
    % to the referece config
    ofdmInfo = getOFDMInfo(cfg,parms.Field,parms.RUIndex);
else
    ofdmInfo = parms.cfgOFDM;
end

if parms.DiffOFDMRef
    % If the reference OFDM subcarrier indices differ from those of the
    % waveform configuration then set OFDM info such that the appropriate
    % subcarriers from the waveform configuration are selected
    if isempty(parms.cfgOFDM) 
        ofdmInfoRef = getOFDMInfo(parms.cfgRef,parms.FieldRef,parms.RUIndexRef);
    else
        % User provided OFDM config
        ofdmInfoRef = parms.cfgOFDM;
    end

    % Ratio of subcarrier spacing - ASSUME THE BANDWIDTH IS THE SAME
    r = ofdmInfoRef.FFTLength/ofdmInfo.FFTLength;
    
    % Find the closet subcarrier index of interferer which to each
    % subcarrier index of the reference OFDM configuration. closestSCDist
    % is the distance (in subcarriers), and activeSCInd contains the
    % indices the closest interfering subcarrier for each reference
    % subcarrier. These are the "active" subcarrier indices which are used
    % to extract the appropriate FFT indices and spatial mapping matrix
    % elements.
    [closestSCDist,activeSCInd] = min(abs(ofdmInfo.ActiveFrequencyIndices*r - ...
        ofdmInfoRef.ActiveFrequencyIndices'));
    
    % If the distance between the closest interference subcarrier and the
    % reference subcarrier is large then assume there is no active
    % overlapping interference subcarrier. Create an array of logical
    % indices, inactiveFFTLogInd, indicating inactive interfering
    % subcarriers.
    inactiveFFTLogInd = closestSCDist>r/2;
    
    % The above two processes result in the following:
    % Consider the interference configuration subcarrier spacing is 4x that
    % of the interference.
    %
    %       Interference:  x  x  x  A  x  x  x  B  x  x  x  C  x  x  x  D  x  x  x
    %          Reference:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19
    %
    % The active subcarrier indices are the interference subcarrier indices
    % closest to each reference subcarrier. In the above example there are
    % four indices with values A, B, C, and D. Therefore:
    %
    %        activeSCInd:  1  1  1  1  1  2  2  2  2  3  3  3  4  4  4  4  4  4  4
    %
    % If active subcarriers are too far away they are deemed inactive:
    %
    %  inactiveFFTLogInd:  1  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  1
    %
    % This will result in the following precoding values being used at each
    % reference subcarrier (the inactive ones are set to 0):
    %
    %             result:  0  A  A  A  A  B  B  B  B  C  C  C  C  D  D  D  D  D  0
    
    % Update OFDM configuration of interference for subcarriers which will
    % be used for the reference configuration. Note inactive subcarriers
    % are included. Do not update ofdmInfo.NumTones as used for other
    % normalization.
    ofdmInfo.ActiveFFTIndices = ofdmInfo.ActiveFFTIndices(activeSCInd);
    ofdmInfo.ActiveFrequencyIndices = ofdmInfo.ActiveFFTIndices-(ofdmInfo.FFTLength/2+1);
else
    % All subcarriers to be used for reference
    activeSCInd = 1:ofdmInfo.NumTones;
    inactiveFFTLogInd = false(1,ofdmInfo.NumTones);
end

if parms.SubsampleFactor>1
    % Subsample the subcarriers. Do not update ofdmInfo.NumTones as used
    % for other normalization so required number in signal required.
    activeSCInd = activeSCInd(1:parms.SubsampleFactor:end);
    inactiveFFTLogInd = inactiveFFTLogInd(1:parms.SubsampleFactor:end);
    ofdmInfo.ActiveFFTIndices = ofdmInfo.ActiveFFTIndices(1:parms.SubsampleFactor:end);
    ofdmInfo.ActiveFrequencyIndices = ofdmInfo.ActiveFFTIndices-(ofdmInfo.FFTLength/2+1);
end

% Get the cyclic shift per space-time stream or transmit antenna depending
% on the format and field. For Non-HT format or preamble, the shift is per
% transmit antenna. Create a 'mock' channel estimate of the correct
% dimensions to apply the cyclic shift.
cbw = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth);
isTxAntCSD = strcmp(parms.Field,'preamble') || isa(cfg,'wlanNonHTConfig');
if isTxAntCSD
    csh = wlan.internal.getCyclicShiftVal('OFDM',cfg.NumTransmitAntennas,cbw);
else
    switch class(cfg)
        case 'wlanHEMUConfig'
            allocInfo = ruInfo(cfg);
            numSTS = allocInfo.NumSpaceTimeStreamsPerRU(parms.RUIndex);
            csh = wlan.internal.getCyclicShiftVal('VHT',numSTS,cbw); % Same CSD for HE, VHT, and HT
        case 'wlanHETBConfig'
            stsIdx = cfg.StartingSpaceTimeStream-1+(1:cfg.NumSpaceTimeStreams).';
            numSTSTotal = stsIdx(end);
            cshAll = wlan.internal.getCyclicShiftVal('VHT',numSTSTotal,cbw);
            csh = cshAll(stsIdx);
        otherwise % 'wlanHESUConfig','wlanVHTConfig','wlanHTConfig'
            csh = wlan.internal.getCyclicShiftVal('VHT',cfg.NumSpaceTimeStreams,cbw); % Same CSD for HE, VHT, and HT
    end
end

% Get cyclic shift per subcarrier each space-time stream/transmit antenna
csdTmp = exp(-1i*2*pi*csh.'.*ofdmInfo.ActiveFrequencyIndices/ofdmInfo.FFTLength);
if isTxAntCSD
    % CSD applied over second dimension so permute to third dimension to represent transmit antennas
    csd = permute(csdTmp,[1 3 2]);
else
    csd = csdTmp;
end

% If subcarriers are deemed to be inactive then zero them - this will "turn
% them off" in calculations using the precoding matrix
csd(inactiveFFTLogInd,:,:) = 0;

end

function Q = getSpatialMappingMatrix(cfg,ruIdx,ofdmInfo,activeSCInd)
%getSpatialMappingMatrix Returns spatial mapping matrix used.
%   Q = getSpatialMappingMatrix(CFG,RUIDX,OFDMINFO,ACTIVESCIND) returns the
%   spatial mapping matrix used for each occupied subcarrier in the data
%   portion.
%
%   Q is Nst-by-Nsts-by-Ntx where Nst is the number of occupied
%   subcarriers, Nsts is the number of space-time streams, and Ntx is the
%   number of transmit antennas.
%
%   CFG is a format configuration object.
%
%   RUIDX is the index of the RU of interest. This is used to extract an RU
%   if CFG is of type wlanHEMUConfig.
%
%   OFDMINFO is the OFDM info structure.
%
%   ACTIVESCIND is an array containing subcarrier indices to use within
%   active RU subcarriers - this allows for subsampling of the spatial
%   mapping matrix.

    if isa(cfg,'wlanHEMUConfig')
        allocInfo = ruInfo(cfg);
        assert(ruIdx>0)
        numSTS = allocInfo.NumSpaceTimeStreamsPerRU(ruIdx);
        mappingType = cfg.RU{ruIdx}.SpatialMapping;
        mappingMatrix = cfg.RU{ruIdx}.SpatialMappingMatrix;
    else
        numSTS = sum(cfg.NumSpaceTimeStreams); % For VHT might be a vector
        mappingType = cfg.SpatialMapping;
        mappingMatrix = cfg.SpatialMappingMatrix;
    end
    numTx = cfg.NumTransmitAntennas;
    Nst = numel(ofdmInfo.ActiveFrequencyIndices); % ofdmInfo.NumTones is original size (not subsampled so use subsampled vector)

    switch mappingType
        case 'Direct'
            Q = repmat(permute(eye(numSTS,numTx),[3 1 2]),Nst,1,1);
        case 'Hadamard'
            hQ = hadamard(8);
            normhQ = hQ(1:numSTS,1:numTx)/sqrt(numTx);
            Q = repmat(permute(normhQ,[3 1 2]),Nst,1,1);
        case 'Fourier'
            [g1, g2] = meshgrid(0:numTx-1, 0:numSTS-1);
            normQ = exp(-1i*2*pi.*g1.*g2/numTx)/sqrt(numTx);
            Q = repmat(permute(normQ,[3 1 2]),Nst,1,1);
        otherwise % 'Custom'            
            if ismatrix(mappingMatrix) && (size(mappingMatrix, 1) == numSTS) && (size(mappingMatrix, 2) == cfg.NumTransmitAntennas)
                % MappingMatrix is Nsts-by-Ntx
                Q = repmat(permute(normalize(mappingMatrix(1:numSTS, 1:numTx),numSTS),[3 1 2]),Nst,1,1);
            else
                % MappingMatrix is Nst-by-Nsts-by-Ntx
                Q = mappingMatrix(activeSCInd,:,:); % Extract active subcarriers to use from the mapping matrix
                Qp = permute(Q,[2 3 1]);
                Qn = coder.nullcopy(complex(zeros(numSTS,numTx,Nst)));
                for i = 1:Nst
                    Qn(:,:,i) = normalize(Qp(:,:,i),numSTS); % Normalize mapping matrix
                end
                Q = permute(Qn,[3 1 2]);
            end
    end
end

function Q = normalize(Q,numSTS)
% Normalize mapping matrix
    Q = Q * sqrt(numSTS)/norm(Q,'fro');
end

function ofdmInfo = getOFDMInfo(cfg,field,varargin)
% Return a structure containing the OFDM configuration for a field and
% configuration.
    if strcmp(field,'data')
        % Get OFDM info for data fields of formats
        switch class(cfg)
            case 'wlanHEMUConfig'
                ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg,varargin{:});
            case {'wlanHESUConfig','wlanHETBConfig'}
                ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg);
            case 'wlanVHTConfig'
                ofdmInfo = wlanVHTOFDMInfo('VHT-Data',cfg);
            case 'wlanHTConfig'
                ofdmInfo = wlanHTOFDMInfo('HT-Data',cfg);
            case 'wlanNonHTConfig'
                ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg.ChannelBandwidth);
            otherwise
                error('Unexpected format');
        end
    else % 'preamble'
        % Get OFDM info for preamble fields of formats
        switch class(cfg)
            case {'wlanHEMUConfig','wlanHESUConfig','wlanHETBConfig'}
                ofdmInfo = wlanHEOFDMInfo('HE-SIG-A',cfg);
            case 'wlanVHTConfig'
                ofdmInfo = wlanVHTOFDMInfo('VHT-SIG-A',cfg);
            case 'wlanHTConfig'
                ofdmInfo = wlanHTOFDMInfo('HT-SIG',cfg);
            case 'wlanNonHTConfig'
                ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg.ChannelBandwidth);
            otherwise
                error('Unexpected format');
        end
    end
end

function W = getOFDMAPrecodingMatrix(cfg,field,cfgRef,fieldRef,ruIdxRef,subsampleFactor)
% Return a cell array of matrices as the configuration of interest is OFDMA
% and therefore, multiple RUs may contribute to the precoding matrix at
% reference subcarriers.

    % Get the precoding matrix for each RU at reference subcarriers and
    % find the number of overlapping subcarriers in each RU.
    allocInfo = ruInfo(cfg);
    Q = cell(1,allocInfo.NumRUs);
    activeSCPerRU = cell(1,allocInfo.NumRUs);
    numActiveSCPerRU = zeros(1,allocInfo.NumRUs);
    for iru = 1:allocInfo.NumRUs
        Qtmp = hGetPrecodingMatrix(cfg,iru,field,cfgRef,ruIdxRef,fieldRef,subsampleFactor);
        Q{iru} = Qtmp;
        activeSCPerRUtmp = all(all(Qtmp~=0,3),2);
        activeSCPerRU{iru} = activeSCPerRUtmp;
        numActiveSCPerRU(iru) = sum(activeSCPerRUtmp);
    end

    % Find which RUs contribute to the precoding at the reference location
    % as they have active subcarriers
    activeRU = numActiveSCPerRU>0;
    numActiveRUs = sum(activeRU);

    if numActiveRUs==0
        % Return an zeros precoding matrix the size of the reference (use 1
        % space-time stream) as no RUs active
        W = {zeros(size(Qtmp,1),1,cfg.NumTransmitAntennas)};
        return
    end
    
    activeRUInd = find(activeRU);
    lastActiveRUInd = activeRUInd(end);

    % Find any subcarriers which are not active in any of the precoding RUs
    % and therefore will have "0" precoding
    inactiveSC = true(size(Q{iru},1),1);
    for iru = 1:numActiveRUs
        idx = activeRUInd(iru); % Index of RU to use
        inactiveSC(activeSCPerRU{idx}) = false;
    end

    % Handle zero precoding subcarriers by appending or prepending to an active RUs
    inactiveSCInd = find(inactiveSC);
    prependToRUidx = zeros(1,numel(inactiveSCInd));
    appendToRUidx = zeros(1,numel(inactiveSCInd));
    for iia = 1:numel(inactiveSCInd)
        idx = find(inactiveSCInd(iia)<cumsum(numActiveSCPerRU),1,'first');
        if ~isempty(idx)
            % Treat zero subcarrier as part of next RU
            prependToRUidx(iia) = idx;
            numActiveSCPerRU(idx) = numActiveSCPerRU(idx)+1;
        else
            % If idx is empty it means 0 subcarriers occur after the last RU
            appendToRUidx(iia) = lastActiveRUInd;
        end
    end

    W = cell(1,numActiveRUs);
    for iru = 1:numActiveRUs
        % Extract active subcarriers from RU
        idx = activeRUInd(iru); % Index of RU to use
        if any(idx==prependToRUidx) || any(idx==appendToRUidx)
            % Prepend and append zeros subcarriers to RU and
            [~,Nsts,Ntx] = size(Q{idx});
            numZerosPrepend = sum(idx==prependToRUidx);
            numZerosAppend = sum(idx==appendToRUidx);
            W{iru} = [zeros(numZerosPrepend, Nsts, Ntx); Q{idx}(activeSCPerRU{idx},:,:); zeros(numZerosAppend, Nsts, Ntx)]; % Extract active subcarriers from it
        else
            W{iru} = Q{idx}(activeSCPerRU{idx},:,:);
        end
    end

end