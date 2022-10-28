classdef hFrameFormats
%hFrameFormats Indicate the physical layer format of a WLAN MAC frame
%
%   FORMAT = hFrameFormats creates an object with all the supported frame
%   format values. All the supported values are mentioned below.
%
%   hFrameFormats properties: 
%
%   NonHT(0)     - Non-HT frame format
%   HTMixed(1)   - HT-Mixed frame format
%   VHT(2)       - VHT frame format
%   HE_SU(3)     - HE single user frame format
%   HE_EXT_SU(4) - HE extended range single user frame format
%   HE_MU(5)     - HE multi-user frame format

%   Copyright 2021 The MathWorks, Inc. 

    properties (Constant)
        % Non-HT frame format
        NonHT = 0
        
        % HT-Mixed frame format
        HTMixed = 1
        
        % VHT frame format
        VHT = 2
        
        % HE single user frame format
        HE_SU = 3
        
        % HE extended range single user format
        HE_EXT_SU = 4
        
        % HE multi-user format
        HE_MU = 5
    end

    methods(Static)
        function formatString = getFrameFormatString(formatConstant, layer)
            if strcmp(layer, 'PHY')
                switch formatConstant
                    case hFrameFormats.NonHT
                        formatString = 'NonHT';
                    case hFrameFormats.HTMixed
                        formatString = 'HTMixed';
                    case hFrameFormats.VHT
                        formatString = 'VHT';
                    case hFrameFormats.HE_SU
                        formatString = 'HE_SU';
                    case hFrameFormats.HE_EXT_SU
                        formatString = 'HE_EXT_SU';
                    case hFrameFormats.HE_MU
                        formatString = 'HE_MU';
                end
            elseif strcmp(layer, 'MAC')
                switch formatConstant
                    case hFrameFormats.NonHT
                        formatString = 'Non-HT';
                    case hFrameFormats.HTMixed
                        formatString = 'HT-Mixed';
                    case hFrameFormats.VHT
                        formatString = 'VHT';
                    case hFrameFormats.HE_SU
                        formatString = 'HE-SU';
                    case hFrameFormats.HE_EXT_SU
                        formatString = 'HE-EXT-SU';
                    case hFrameFormats.HE_MU
                        formatString = 'HE-MU';
                end
            end
        end

        function formatConstant = getFrameFormatConstant(formatString)
            switch formatString
                case {'HE-MU', 'HE_MU'}
                    formatConstant = hFrameFormats.HE_MU;
                case {'HE-SU', 'HE_SU'}
                    formatConstant = hFrameFormats.HE_SU;
                case {'HE-EXT-SU', 'HE_EXT_SU'}
                    formatConstant = hFrameFormats.HE_EXT_SU;
                case 'VHT'
                    formatConstant = hFrameFormats.VHT;
                case {'HT-MF', 'HT-Mixed', 'HTMixed'}
                    formatConstant = hFrameFormats.HTMixed;
                case {'Non-HT', 'NonHT'}
                    formatConstant = hFrameFormats.NonHT;
                otherwise % Unsupported frame formats like HT_GF
                    formatConstant = -1;
            end
        end
    end
end
