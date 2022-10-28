function [sinr,Stxrx,Istxrx,Iotxrx,N] = hCalculateSINR(Htxrx,Ptxrx,varargin)
%hCalculateSINR calculate the SINR of a link given interferers
%   SINR = hCalculateSINR(HWTXRX,PTXRX,N0) returns the SINR in decibels
%   assuming no interferers.
%
%   SINR is a Nst-by-Nsts array containing the SINR in decibels per
%   subcarrier and space-time stream. Nst is the number of subcarriers and
%   Nsts is the number of space-time streams.
%
%   HWTXRX is a Nst-by-Nsts-by-Nr array containing the effective channel of
%   interest. Nr is the number of receive antennas.
%
%   Ptxrx is the power in Watts of the signal of interest.
%
%   N0 is the noise power in Watts.
%
%   SINR = hCalculateSINR(...,HWTXRX_INT,PTXRX_INT) calculates the SINR
%   assuming interfering transmissions.
%
%   HWTXRX_INT is a cell array of Nint arrays containing the effective
%   channel between each interferer and the receiver. Each element is a
%   Nst-by-Nsts_int-by-Nr array.
%
%   PTXRX_INT is a column vector of length Nint containing the interference
%   power in Watts for each interferer, where Nint is the number of
%   interferers.
%
%   SINR = hCalculateSINR(HTXRX,PTXRX,WTX,N0) returns the SINR in decibels
%   assuming no interferers for separate channel and precoding matrices.
%
%   Htxrx is a Nst-by-Nt-by-Nr array containing the channel of interest. Nt
%   is the number of transmit antennas and Nr is the number of receive
%   antennas.
%
%   Wtx is a Nst-by-Nsts-by-Nt array containing precoding of signal of
%   interest.
%
%   SINR = hCalculateSINR(...,HTXRX_INT,PTXRX_INT,WTX_INT) calculates the
%   SINR assuming interfering transmissions for separate channel and
%   precoding matrices.
%
%   HTXRX_INT is a cell array of Nint arrays containing the channel between
%   each interferer and the receiver. Each element is a Nst-by-Nt_int-by-Nr
%   array.
%
%   WTX_INT is a cell array with Nint elements containing the precoding
%   applied at each interferer. Each element is a Nst-by-Nsts_int-by-Nt_int
%   array, or a cell array containing sets of precoding matrices which make
%   up the required number of subcarriers. A cell array per interferer
%   allows for an OFDMA scenario were different interfering RUs which
%   overlap the subcarriers of interest may use different precoding
%   matrices and have different numbers of space-time streams.
%
%   % Example: Calculate the SINR for a link with one interferer
%   Psoi = -20; % Signal of interest received power (dBm)
%   Pint = -45; % Interfering signal received power (dBm)
%   N0 = -85;   % Noise power (dBm)
%   Hsoi = rand(242,1); % Channel of interest
%   W = ones(242,1); % Precoding matrix (assume no precoding)
%   Hint = rand(242,1); % Channel of interest
%   sinr = hCalculateSINR(Hsoi,db2pow(Psoi-30),W,db2pow(N0-30),{Hint},db2pow(Pint-30),{W});
%
%   See also hTGaxLinkPerformanceModel.

%   Copyright 2021 The MathWorks, Inc.

%#codegen

% Check sizes are compatible for channel matrix and precoding matrix
[Nst,Ntsts,Nr] = size(Htxrx);

% Default no interference
Nint = 0;
Ptxrx_int = zeros(0,1); % for code to run

switch nargin
    case 3 % hCalculateSINR(HTXRX,PTXRX,N0)
        N0 = varargin{1};
        Nsts = Ntsts;

        % Generate MMSE receive filter
        Wout = hTGaxMMSEFilter(Htxrx,Ptxrx,N0); % Nst-by-Nr-by-Nsts

    case 4 % hCalculateSINR(HTXRX,PTXRX,WTX,N0)
        [Wtx,N0] = deal(varargin{:});
        [Nst_w,Nsts,Nt_w] = size(Wtx);
        assert(all([Nst Ntsts]==[Nst_w Nt_w]),'Mismatch in precoding and channel matrix dimensions')

        % Generate MMSE receive filter and combine W matrix with H
        [Wout,Htxrx] = hTGaxMMSEFilter(Htxrx,Wtx,Ptxrx,N0); % Nst-by-Nr-by-Nsts

    case 5 % hCalculateSINR(HTXRX,PTXRX,N0,HTXRX_INT,PTXRX_INT)
        [N0,Htxrx_int,Ptxrx_int] = deal(varargin{:});
        Nsts = Ntsts;

        % Generate MMSE receive filter
        Wout = hTGaxMMSEFilter(Htxrx,Ptxrx,N0); % Nst-by-Nr-by-Nsts

        if ~isempty(Htxrx_int)
            % Assume interference is present but if it is an empty cell array then no interference
            Nint = numel(Htxrx_int); % number of interferers
            HW_int = cell(1,Nint); % Cell array of Nst-by-by-Nr-by-Nsts
            for k = 1:Nint
                if ~iscell(Htxrx_int{k})
                    HW_int{k} = permute(Htxrx_int{k},[1 3 2]); % Nst-by-Nr-by-NstsInt
                else
                    for ir = 1:numel(Htxrx_int{k})
                        HW_int{k}{ir} = permute(Htxrx_int{k}{ir},[1 3 2]); % Nst-by-Nr-by-NstsInt
                    end
                end
            end
        end

    case 7 % hCalculateSINR(HTXRX,PTXRX,WTX,N0,HTXRX_INT,PTXRX_INT,WTX_INT)
        [Wtx,N0,Htxrx_int,Ptxrx_int,Wtx_int] = deal(varargin{:});
        [Nst_w,Nsts,Nt_w] = size(Wtx);
        assert(all([Nst Ntsts]==[Nst_w Nt_w]),'Mismatch in precoding and channel matrix dimensions')

        % Generate MMSE receive filter and combine W matrix with H
        [Wout,Htxrx] = hTGaxMMSEFilter(Htxrx,Wtx,Ptxrx,N0); % Nst-by-Nr-by-Nsts

        % Interference is present
        assert(iscolumn(Ptxrx_int))
    
        % Make sure channel and precoding provided for each interferer
        assert(all(size(Htxrx_int)==size(Wtx_int)),'A channel and precoding matrix must be provided for each interferer')

        if ~isempty(Htxrx_int)
            % Assume interference is present but if it is an empty cell array then no interference
            Nint = numel(Htxrx_int); % Number of interferers
            HW_int = calculateHWInt(Htxrx_int,Wtx_int,Nst,Nr,Nint);
        end 
end

% Calculate signal power (STXRX), inter-stream interference power (ISTXRX),
% and interference power (IOTXRX)
if Nint>0
    % Interference power
    % For each active interferer calculate the power, then sum to create
    % the total interference
    T = Wout; % Nst-by-Nr-by-Nsts
    
    iok = coder.nullcopy(zeros(Nst,Nsts,Nint));
    for k = 1:Nint
        if ~iscell(HW_int{k})
            for j = 1:Nsts
                iok(:,j,k) = sum(abs(sum(T(:,:,j).*HW_int{k},2)).^2,3);
            end
        else
            % The number of streams are different per subcarrier (OFDMA)
            offset = 0;
            for ir = 1:numel(HW_int{k})
                NstInt = size(HW_int{k}{ir},1);
                HiIdx = offset + (1:NstInt);
                for j = 1:Nsts
                    iok(HiIdx,j,k) = sum(abs(sum(T(HiIdx,:,j).*HW_int{k}{ir},2)).^2,3);
                end
                offset = offset+NstInt;
            end
        end
    end
    Iotxrx = sum(permute(Ptxrx_int,[3 2 1]).*iok,3); % Nst-by-Nsts
else
    % No interference
    Iotxrx = zeros(Nst,Nsts);
end

if Nsts==1 && Nr==1
    % SISO
    N = (abs(Wout).^2)*N0; % Noise power
    % Use the channel estimate directly rather than the
    % channel matrix and precoding matrix
    equalized = Wout.*Htxrx;
    Stxrx = Ptxrx.*abs(equalized).^2;
    Istxrx = Ptxrx.*equalized.^2-Stxrx;
else
    % MIMO
    HtxrxP = permute(Htxrx,[3 2 1]); % Permute to Nr-by-Nsts-by-Nst
    WoutT = permute(Wout,[2 3 1]); % Permute to Nr-by-Nsts-by-Nst
    Stxrx = coder.nullcopy(zeros(Nst,Nsts));
    Istxrx = coder.nullcopy(zeros(Nst,Nsts));
    N = coder.nullcopy(zeros(Nst,Nsts));
    for j = 1:Nsts
        for m = 1:Nst                
            Tj = WoutT(:,j,m);

            % Noise power
            N(m,j) = (norm(Tj).^2)*N0;

            % Use the channel estimate directly rather than the
            % channel matrix and precoding matrix
            HW = HtxrxP(:,:,m);
            Stxrx(m,j) = Ptxrx*abs(Tj.'*HW(:,j)).^2;
            Istxrx(m,j) = Ptxrx*norm(Tj.'*HW).^2-Stxrx(m,j);
        end
    end
end

% Nst-by-Nsts-by-Nlinks
sinrLin = Stxrx./(Istxrx + Iotxrx + N);

% Return in dB
sinr = 10*log10(abs(sinrLin)); % abs protects against very small negative values due to numeric precision

end

function HW_int = calculateHWInt(Htxrx_int,Wtx_int,Nst,Nr,Nint)
    for ic = 1:numel(Htxrx_int)
        % Check sizes are compatible for each precoding and channel
        % matrix and with the channel of interest
        
        [Nst_hi,Nt_hi,Nr_hi] = size(Htxrx_int{ic});
        assert(all([Nst_hi Nr_hi]==[Nst Nr]),'Mismatch in precoding and channel matrix dimensions for interferer')
        
        if ~iscell(Wtx_int{ic})
            [Nst_wi,~,Nt_wi] = size(Wtx_int{ic});
            assert(all([Nst_hi Nt_hi]==[Nst_wi Nt_wi]),'Mismatch in precoding and channel matrix dimensions for interferer')
        else
            Nstint = 0;
            for ir = 1:numel(Wtx_int{ic})
                [Nstintt,~,Ntxintt] = size(Wtx_int{ic}{ir});
                Nstint = Nstint+Nstintt;
                assert(all(Nt_hi==Ntxintt),'Mismatch in precoding and channel matrix dimensions for interfere')
            end
            % Sum of subcarriers for all RUs must equal number of subcarriers in channel
            assert(Nst_hi==Nstint,'Mismatch in precoding and channel matrix dimensions for interferer')
        end
    end
    % Permute for efficiency Wtx to Nst-by-Nt-by-Nsts
    Wtx_intT = cell(size(Wtx_int));
    for ic = 1:numel(Wtx_intT)
        if ~iscell(Wtx_int{ic})
            Wtx_intT{ic} = permute(Wtx_int{ic},[1 3 2]);
        else
            % The number of streams are different per subcarrier (OFDMA)
            Wtx_intT{ic} = cell(1,numel(Wtx_int{ic}));
            for ir = 1:numel(Wtx_int{ic})
                Wtx_intT{ic}{ir} = permute(Wtx_int{ic}{ir},[1 3 2]);
            end
        end
    end

    % Calculate H*W for interferers as a vector calculation
    HW_int = cell(1,Nint); % Cell array of Nst-by-Nr-by-Nsts
    for k = 1:Nint
        if ~iscell(Wtx_intT{k})
            Wint = Wtx_intT{k}; % Nst-by-Nt-by-Nsts
            Hi = Htxrx_int{k}; % Nst-by-Nt-by-Nr
            NstsInt = size(Wint,3);
            HW_k = coder.nullcopy(complex(zeros(Nst,Nr,NstsInt)));
            for i = 1:Nr
                for j = 1:NstsInt
                    HW_k(:,i,j) = sum(Hi(:,:,i).*Wint(:,:,j),2);
                end
            end
            HW_int{k} = HW_k;
        else
            % The number of streams are different per subcarrier (OFDMA)
            Wint = Wtx_intT{k}; % Cell of Nst-by-Nt-by-Nsts
            Hi = Htxrx_int{k}; % Nst-by-Nt-by-Nr
            offset = 0;
            for ir = 1:numel(Wint)
                NstsInt = size(Wint{ir},3);
                NstInt = size(Wint{ir},1);
                HW_k_ir = coder.nullcopy(complex(zeros(NstInt,Nr,NstsInt)));
                HiIdx = offset + (1:NstInt);
                for i = 1:Nr
                    for j = 1:NstsInt
                        HW_k_ir(:,i,j) = sum(Hi(HiIdx,:,i).*Wint{ir}(:,:,j),2);
                    end
                end
                HW_int{k}{ir} = HW_k_ir;
                offset = offset+NstInt;
            end
        end
    end
end