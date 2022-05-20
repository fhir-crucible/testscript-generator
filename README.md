# TestScript Generator

## Background and Overview

The TestScript Generator aims to ease the testing process by creating a complete suite of TestScripts to be leveraged against any FHIR endpoint that conforms to a given Implementation Guide (IG). *__The generator accomplishes this through several steps__*:

> - Unzips, processes, and stores the IG(s) contained within the `/igs` directory
>
> - For each stored IG, extracts the resource-level interactions outlined in the server-side Capability Statement 
> 
> - Filters those interactions by conformance level (i.e. **SHALL**, **SHOULD**, **MAY**) and creates groups of tests categorized by their level of conformance 
>   - See the __*Generation Methodology*__ section for more information on how tests are created
> - Writes the generated tests out to the `/testscripts` directory, organizing them by their related conformance level 


This generator is intended to be used in concert with the [TestScript Engine](https://github.com/fhir-crucible/testscript-engine): users can auto-create TestScripts with this generator and then execute them against endpoint(s) with the engine. Currently, there is no pipeline between the generator and the engine, and any generated TestScripts must be manually transferred to the `/TestScripts` directory within the engine's directory structure. 

## Generation Methodology 

Currently, generated TestScripts test one resource-level interactions on individual resource types (*e.g.*, read an AllergyIntolerance or create a Patient). Further, these tests are categorized by their conformance level. 

Therefore, this means any generated test with a **SHALL** conformance level only utilizes interactions that **SHALL** be supported by the IG implementation. For some interactions this is a non-factor: consider the *search* interaction. A *search* can be done without any prior knowledge about the data stored on the implementation and all relevant Resources saved on an endpoint will be served as a bundle response to a system-level *search* request. Server-specific information such as unique Resource IDs are not required in order to test the *search* interaction.

This is not the case for an interaction like *read*, where a unique ID is required for any *read* request. Therefore, to test interactions like *read* that require a specific ID, the test needs either prior knowledge of the data stored on the server __OR__ to utilize another interaction during setup to dynamically discover a testable unique ID. For example, if both *read* and *search* interactions *SHALL* be supported by an endpoint, the generated test will perform a system-level Resource *search* during setup, store the returned bundle of Resources, extract a unique ID from the bundle using a variable, and then use that unique ID with a subsequent *read* interaction.

The generator does the legwork of first determining what information is necessary to test an interaction and then deciding how to piece together interactions of the same conformance level to accomplish this 'dynamic discovery'.

## Future Directions

- [ ] Explore TestScript generation informed by alternatives to IGs
    - Cucumber/Gherkin syntax
    - ExampleScenario Resources
- [ ] Increase variety in how TestScript generation is organized
    - Instead of generating/storing by conformance level, generate by interaction type or by resource
- [ ] Command-line option for pipeline between TestScript Generator and TestScript Engine
- [ ] Generating tests that verify multi-system interactions 
    
## Running the Generator

**Commands:**
  - `bundle install`
    - Functionality
      - This installs the dependencies specified in the Gemfile, allowing the generator to run. Run this command after downloading the repo and before running `ruby driver.rb` for the first time. 
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