function frequency = hChannelToFrequency(channelNumber, band, varargin)
%hChannelToFrequency Return center frequency for the given channel number
%
%   FREQUENCY = hChannelToFrequency(CHANNELNUMBER, BAND) returns the center
%   frequency for the channel number specified by CHANNELNUMBER, in the
%   band specified by BAND.
%
%   FREQUENCY is the frequency value returned in units of GHz.
%
%   CHANNELNUMBER specifies the channel number.
%
%   BAND specifies the band in GHz as 2.4, 5, or 6.
%
%   FREQUENCY = hChannelToFrequency(..., CHANNELSTARTINGFACTOR) also
%   specifies the CHANNELSTARTINGFACTOR for 5 GHz or 6 GHz bands.
%
%   CHANNELSTARTINGFACTOR is the base factor from which channel center
%   frequencies are calculated. This number is multiplied by 500 kHz to
%   form the base frequency to be added to the 'CHANNELNUMBER x 5'
%   MHz. Default channel starting factor value is 10000.

%   Copyright 2021 The MathWorks, Inc.

switch band
    case 2.4 % 2.4 GHz
        assert((channelNumber >= 1 && channelNumber <= 13), 'Invalid channel number for 2.4 GHz band');
        startingFreq2GHz = 2407;
        
        % Refer IEEE 802.11-2016, section 19.3.15.2
        frequency = startingFreq2GHz + 5*channelNumber;
        
    case 5 % 5 GHz
        channelStartingFactor5GHz = 10000;
        assert((channelNumber >= 1 && channelNumber <= 200), 'Invalid channel number for 5 GHz band');
        if ~isempty(varargin)
            assert(isnumeric(varargin{1}) && isscalar(varargin{1}), 'Channel starting factor must be a scalar number');
            channelStartingFactor5GHz = varargin{1};
        end
        
        % Refer IEEE 802.11-2016, section 19.3.15.3
        frequency = channelStartingFactor5GHz*0.5 + 5*channelNumber;
        
    case 6 % 6 GHz
        % Channel starting factor is not defined in the IEEE P802.11-D7.0.
        % The value for starting factor is chosen as 11880 to result in
        % starting frequency 5.940 GHz, which is taken from the document
        % reference:
        % https://mentor.ieee.org/802.11/dcn/16/11-16-1348-06-00ax-coexistence-assurance.docx
        channelStartingFactor6GHz = 11880;
        assert((channelNumber >= 1 && channelNumber <= 233), 'Invalid channel number for 6 GHz band');
        if ~isempty(varargin)
            assert(isnumeric(varargin{1}) && isscalar(varargin{1}), 'Channel starting factor must be a scalar number');
            channelStartingFactor6GHz = varargin{1};
        end
        
        % Refer IEEE P802.11ax-D7.0, section 27.3.23.2
        frequency = channelStartingFactor6GHz*0.5 + 5*channelNumber;

    otherwise
        error('Unknown band ID');
end
frequency = frequency/1000;
end