function [W,varargout] = hTGaxMMSEFilter(varargin)
%hTGaxMMSEFilter MMSE linear filter weights
%   W = hTGaxMMSEFilter(H,V,P,N0) returns linear MMSE receive filter given
%   the channel matrix and precoding matrix used at the transmitter.
%
%   W is a Nst-by-Nr-by-Nsts matrix containing the MMSE coefficients. Nst
%   is the number of subcarriers, Nr is the number of receive antennas, and
%   Nsts is the number of space-time streams.
%
%   H is a Nst-by-Nt-by-Nr array containing the channel. Nt is the number
%   of transmit antennas.
%
%   V is a Nst-by-Nsts-by-Nt array containing the precoding matrix (spatial
%   mapping + cyclic shift).
%
%   P is the receiver power in Watts.
%
%   N0 is the receiver noise power in Watts.
%
%   W = hTGaxMMSEFilter(HV,P,N0) returns linear MMSE receive filter where
%   HV is a Nst-by-Nsts-by-Nrx-by-Nlinks array containing the channel
%   response with precoding (spatial mapping + cyclic shift) included.
%
%   [W,HV] = hTGaxMMSEFilter(...) additionally returns the
%   Nst-by-Nsts-by-Nr combined channel and precoding matrix.
%
%   % Example: Generate MMSE equalizer weights
%   H = rand(242,2); % Channel of interest
%   V = ones(242,1,2); % Precoding matrix
%   P = -60; % dBW - Signal power
%   N0 = -120; % dBW - Noise power
%   W = hTGaxMMSEFilter(H,V,db2pow(P),db2pow(N0));
%
%   See also hCalculateSINR.

%   Copyright 2021 The MathWorks, Inc.

%#codegen

if nargin==4
    % hTGaxMMSEFilter(H,V,P,N0)
    % H is a Nst-by-Ntx-by-Nrx array containing the channel
    % response
    % V is a Nst-by-Nsts-by-Ntx array containing the precoding
    % matrix (spatial mapping + cyclic shift)
    % N0 is the noise variance
    [H,V,P,N0] = varargin{:};
    [Nst,Ntx,Nrx] = size(H);
    [Nst_w,Nsts,Ntx_w] = size(V);
    assert(all([Nst Ntx]==[Nst_w Ntx_w]))
    
    % The combined channel matrix estimated by the receiver includes
    % precoding and the channel response. Create this as it will be used by
    % the linear receiver
    Vp = permute(V,[1 3 2]); % Nst-by-Ntx-by-Nsts
    Hc = coder.nullcopy(complex(zeros(Nst,Nrx,Nsts)));
    for i = 1:Nrx
        for j = 1:Nsts
            Hc(:,i,j) = sum(H(:,:,i).*Vp(:,:,j),2);
        end
    end
    Hcp = permute(Hc,[3 2 1]); % Nsts-by-Nrx-by-Nst
    if nargout>1
        varargout{1} = permute(Hc,[1 3 2]); % Nst-by-Nsts-by-Nr
    end
else
    % hTGaxMMSEFilter(HV,P,N0)
    % HV is a Nst-by-Nsts-by-Nrx array containing the channel
    % response with precoding (spatial mapping + cyclic shift) included. N0
    % is the noise variance
    [Hc,P,N0] = varargin{:};
    [Nst,Nsts,Nrx] = size(Hc);
    Hcp = permute(Hc,[2 3 1]); % Nsts-by-Nrx-by-Nst
    if nargout>1
        varargout{1} = Hc; % Nst-by-Nsts-by-Nr
    end
end

% Calculate the linear receiver to be used at the receiver
if Nsts==1 && Nrx==1
    % SISO
    Hc = Hc.*sqrt(P);
    Hdash = conj(Hc);
    W = Hdash./(Hdash.*Hc + N0);
else
    % MIMO
    W = coder.nullcopy(complex(zeros(Nst,Nrx,Nsts)));
    eyensts = eye(Nsts);
    noiseesteye = N0*eyensts;
    Hcp = Hcp.*sqrt(P);
    for i = 1:Nst
        % Calculate the linear receiver matrix
        Hsc = Hcp(:,:,i);
        invH = (Hsc*Hsc'+noiseesteye)\eyensts;
        Wsc = Hsc'*invH;
        W(i,1:Nrx,1:Nsts) = Wsc;
    end
end
end
