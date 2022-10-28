%% Get Code Description of Generated Code
% You can use the code descriptor API to obtain meta-information about the 
% generated code. For each model build, the code generator, by default, 
% creates a |codedescriptor.dmr| file in the build folder. When simulating 
% the model in Accelerator and Rapid Accelerator modes, the 
% |codedescriptor.dmr| is not generated.
%
% You can use the code descriptor API once the code is generated. Use the 
% code descriptor API to describe these items in the generated code:
%
% * Data Interfaces: inports, outports, parameters, data stores, and internal 
%   data.
% * Function Interfaces: initialize, output, update, and terminate.
% * Run-time information of the data and function interfaces, such as 
%   timing requirements of each interface entity.
% * Model hierarchy information and code description of referenced models.


%% Get Data Interface Information
% The <docid:rtw_ref#mw_26d2d2fc-0b55-43c1-8a9c-b98c8df45413 |coder.descriptor.DataInterface|> 
% object describes various properties for a specified data interface 
% in the generated code. In the model |rtwdemo_comments|, there are four 
% inports, one outport, and a tunable external parameter. For more information 
% about the data interfaces in your model, use the 
% <docid:rtw_ref#mw_aa6e1dd0-58d4-4870-83b1-ecec7d45d988 |coder.codedescriptor.CodeDescriptor|> 
% object and its methods.
%
%%
% 1. Create a temporary folder for the build and inspection process.
currentDir = pwd;
[~,cgDir] = rtwdemodir();
%%
% 2. Open and build the model.
open_system('rtwdemo_comments');
evalc('slbuild(''rtwdemo_comments'')');
%%
% 3. Create a |coder.codedescriptor.CodeDescriptor| object for the required 
% model by using the <docid:rtw_ref#mw_06472bf4-9cde-4804-88de-cebd4a4bcf84 
% |getCodeDescriptor|> function.
codeDescriptor = coder.getCodeDescriptor('rtwdemo_comments');
%%
% 4. To obtain a list of all the data interface types in the generated code, 
% use the <docid:rtw_ref#mw_a1c9ed1b-45ad-4ef2-ac21-e0be322f02a0 
% |getDataInterfaceTypes|> method.
dataInterfaceTypes = codeDescriptor.getDataInterfaceTypes()
%%
% To obtain a list of all the supported data interfaces, use the 
% <docid:rtw_ref#mw_2ba26c42-8a3f-4331-986b-736760842ee7 |getAllDataInterfaceTypes|> 
% method.
%%
% 5. To obtain more information about a particular data interface type, use 
% the <docid:rtw_ref#mw_3a603047-d411-479a-8590-cfdc42f7ae5d |getDataInterfaces|> 
% method.
dataInterface = codeDescriptor.getDataInterfaces('Inports');
%%
% This method returns properties of the Inport blocks in the generated code.
%%
% 6. Because this model has four inports, |dataInterface| is an array of 
% |coder.descriptor.DataInterface| objects. Obtain the details of the first 
% Inport of the model by accessing the first location in the array.
dataInterface(1)
%% Get Function Interface Information
% The function interfaces are the entry-point functions in the generated code. 
% In the model |rtwdemo_roll|, the entry-point functions are |model_initialize|, 
% |model_step|, and |model_terminate|. For more information about the 
% function interfaces in your model, use the 
% <docid:rtw_ref#mw_56aac9e0-96aa-4fca-a9b3-d9c01b38d6e4 
% |coder.codedescriptor.FunctionInterface|> 
% object.
%%
% 1. Create a temporary folder for the build and inspection process.
currentDir = pwd;
[~,cgDir] = rtwdemodir();
%%
% 2. Open and build the model.
open_system('rtwdemo_roll');
evalc('slbuild(''rtwdemo_roll'')');
%%
% 3. Create a |coder.codedescriptor.CodeDescriptor| object for the required 
% model by using the <docid:rtw_ref#mw_06472bf4-9cde-4804-88de-cebd4a4bcf84 
% |getCodeDescriptor|> function.
codeDescriptor = coder.getCodeDescriptor('rtwdemo_roll');
%%
% 4. To obtain a list of all the function interface types in the generated code, 
% use the <docid:rtw_ref#mw_27195938-907b-447b-8877-d7f3bd42348c 
% |getFunctionInterfaceTypes|> method.
functionInterfaceTypes = codeDescriptor.getFunctionInterfaceTypes()
%%
% To obtain a list of all the supported function interfaces, use the 
% <docid:rtw_ref#mw_181b702e-ab02-40d7-8cc1-9cb32c27f945 |getAllFunctionInterfaceTypes|> 
% method.
%%
% 5. To obtain more information about a particular function interface type, use 
% the <docid:rtw_ref#mw_190f78db-a992-45c2-b43f-f9b82f7ddf75 |getFunctionInterfaces|> 
% method. 
functionInterface = codeDescriptor.getFunctionInterfaces('Initialize')
%%
% 6. You can further expand on the properties to obtain detailed information. 
% To get the function return value, name, and arguments:
functionInterface.Prototype
%% Get Model Hierarchy Information
% Use the |coder.codedescriptor.CodeDescriptor| object to get the entire 
% model hierarchy information. The model |rtwdemo_async_mdlreftop| has model 
% |rtwdemo_async_mdlrefbot| as the referenced model.
%
% 1. Create a temporary folder for the build and inspection process.
currentDir = pwd;
[~,cgDir] = rtwdemodir();
%%
% 2. Open and build the model.
open_system('rtwdemo_async_mdlreftop');
evalc('slbuild(''rtwdemo_async_mdlreftop'')');
%%
% 3. Create a |coder.codedescriptor.CodeDescriptor| object for the required 
% model by using the <docid:rtw_ref#mw_06472bf4-9cde-4804-88de-cebd4a4bcf84 
% |getCodeDescriptor|> function.
codeDescriptor = coder.getCodeDescriptor('rtwdemo_async_mdlreftop');
%%
% 4. Get a list of all the referenced models by using the 
% <docid:rtw_ref#mw_246feee7-c815-493e-9963-9554a51456d0 
% |getReferencedModelNames|> method.
refModels = codeDescriptor.getReferencedModelNames()
%%
% 5. To obtain the |coder.codedescriptor.CodeDescriptor| object for the 
% referenced model, use the <docid:rtw_ref#mw_fd7b6498-9fc4-4676-8e4c-c05bba9857c0 
% |getReferencedModelCodeDescriptor(refModelName)|> method.
refCodeDescriptor = codeDescriptor.getReferencedModelCodeDescriptor('rtwdemo_async_mdlrefbot');
%%
% You can now use the |refCodeDescriptor| object to obtain more information 
% about the referenced model by using all the available methods in the Code 
% Descriptor API.

% Copyright 2019 The MathWorks, Inc.