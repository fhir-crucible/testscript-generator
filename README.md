**Commands:**
  - `ruby driver.rb`
    - Functionality
      - This runs the driver, which is currently the means for running and testing using the generator. It creates TestScripts that test the supported CRUD interactions, as specified by the IG(s). The IG(s) to be used for generation should be added to the `./igs` directory and generated TestScripts will be written out in the `./testscripts` directory. 

**Folders and Files:**
  - `./igs`
  - `./testscripts `
  - driver.rb
    - Currently, the primary method for running this generator. Use the command listed above.
  - generator.rb
    - Utilizes the IGExtractor and TestScriptWorkflow classes to first determine what interactions a conformant FHIR Implementation ought to be able to handle and then to generate workflows to guide the TestScripts that will test these interactions. Finally, it translates the workflows into TestScripts and outputs hem as JSON files in the `./testscripts` folder. 
  - IGExtractor.rb
    - Handles unpacking and loading in FHIR Implementation Guides (IGs) in either .zip or .tgz format. Looks for IGs to be loaded in the `./igs` directory
  - IGResource.rb
    - Class for storing the IGs as they're processed by the IGExtractor.
  - TestScriptWorkflow.rb
    - Given an IG and a target interaction ('create', 'read', etc.), creates the workflow for the TestScript designed to test this interaction. Conceptually, a 'workflow' defines, through its structure, what needs to be accomplished in each section of the TestScript, what information needs to be persisted between the sections, and how that information should be used. 

## License
Copyright 2022 The MITRE Corporation

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at
```
http://www.apache.org/licenses/LICENSE-2.0
```
Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
