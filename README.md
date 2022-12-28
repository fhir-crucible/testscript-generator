
# TestScript Generator

## Background and Overview

The TestScript Generator aims to ease the testing process by creating a suite of [FHIR TestScript](http://www.hl7.org/fhir/testscript.html) instances to be executed against FHIR servers to check conformance to a given Implementation Guide (IG). FHIR IGs include formal definitions of data structure requirements, interaction patterns, and other details that can be used to generate tests. By attempting to use this information to generate tests as TestScript instances the TestScript Generator project seeks to provide feedback to the FHIR community around
- How well the FHIR conformance resources enable test generation and how they might be improved
- How well the TestScript resource supports testing of interest to the community

This generator is intended to be used in concert with the [TestScript Engine](https://github.com/fhir-crucible/testscript-engine): users can auto-create TestScripts with this generator and then execute them against endpoint(s) with the engine.

## Generation Methodology

The generator currently contains several approaches to generation that reflect the experimental nature of this functionality. The common threads are:
1. Use of IG formal conformance resources including [StructureDefinition](http://www.hl7.org/fhir/structuredefinition.html) for [profiles](http://www.hl7.org/fhir/profiling.html) and [CapabilityStatement](https://www.hl7.org/fhir/capabilitystatement.html) instances for [server API capabilities](https://www.hl7.org/fhir/http.html). Additionally, allow supplemental documention in situations where the structured resources don't provide the detail needed to generate the desired tests. 
3. Generation of [TestScript](http://www.hl7.org/fhir/testscript.html) instances following the FHIR [testing methodology](http://www.hl7.org/fhir/testing.html).

Within this framework, a few different approaches to generation have been tried:
1. Indirect Building: create an internal model that looks for information within conformance resources, builds up tests based on them, and translates those tests into [TestScript](http://www.hl7.org/fhir/testscript.html) instances.
2. Direct Templating: write a template [TestScript](http://www.hl7.org/fhir/testscript.html) instance and instantiate it using details from conformance resources using a string-replace approach.
3. Direct Building: build a [TestScript](http://www.hl7.org/fhir/testscript.html) instances using details from the conformance resources to decide what to add to them.

Current experience suggests that a combination of direct templating and building are effective and creation of a library of functions to build common patterns would be worthwhile.

## Generator Capabilities

The generator can currently generate 4 types of tests. The following sections provide details on their capabilities and status.

### Profile Read Tests

The profile read tests are simple tests that read a supplied instance and validate conformance to a profile. In addition, generation supports the creation of a combined search and read test that will use some additional information to create patient-specific searches for profile instances to remove the need to provide individual instance ids and instead provide only a single patient id. 

To generate these specific tests, run `bundle exec bin/testscript_generator read`

### Process
- Unzips, processes, and stores the IG(s) contained within the `/igs` directory
- Identifies all resource profiles
- Instantiates a template TestScript instance that contains the basic outline of the test, including a input variable for the target instance, a read of that instance, and a check for profile conformance
- looks for a file `extra_input/[IG file name, no extension]/profile_scope_search_spec.csv` and if present, uses the information to create a combined search and read test.
- Writes out to files, organized by IG

#### Relevant Code

Uses the template approach under the [templates](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator/templates) directory:
- [read_profile_template.rb](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator/templates/read_profile_template.rb): test generation logic, including simple logic for the individual profile read tests and more complex logic for the combined search and read test
- [read_profile_template.json](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator/templates/read_profile_template.json): base template for an individual profile read test
- [search_and_read_profile_template.json](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator/templates/search_and_read_profile_template.json): base template for an combined search and read test. Minimal details as it is all built up.
- profile_scope_search_spec.json: additional IG-specific input that provides details on the search to use to identify instances of the profile and whether all instances returned by the search should be expected to conform. For a specific ig will look for the file `profile_scope_search_spec.csv` within the `extra_input/[ig directory]` folder where `[ig directory]` will be the name of the loaded zip or tgz file containing the IG without the extention ([example](https://github.com/fhir-crucible/testscript-generator/tree/main/extra_input/us-mCODE/profile_scope_search_spec.csv) for the mCODE pre-STU3 build from December 2022). The csv will have 3 columns with headers `profile`, `search`, and `passCriteria`. Each row has the following information in these columns
  - `profile`: name of the profile from the StructureDefinition `name` element. Profiles in the IG that don't have a corresponding row are not included in the combined test.
  - `search`: search criteria that would go into a FHIR search url, e.g. `code=http://loinc.org|89243-0` to search on a specific LOINC code. Currently only supports a single criteria and the `=` operator. May also be `SPECIFIC` if no scoping search is possible for the profile, in which case a input variable for a specific instance id is included in the generated TestScript. Must be at least one row with the value `ROOT` which indicates this is the patient profile to use. May also be empty if searching on the resource type is sufficient. When a search is performed, the search will also be restricted to the specific patient.
  - `passCriteria`: `all` if all returned instances must conform to the profile. `one` if not all of them will necessarily conform. Not used when `search` is `SPECIFIC` or `ROOT`.

#### Current Status

These read tests are simple and robust. The user experience is not good using the individual tests, but the combined test relies on profiles that have a search that returns only that profile. This is the most complete generation case to date and seems promising, but will need more work on the engine and generation side to fine-tune the feedback and usability.

### Profile Must Support Tests

Must Support tests check that for elements flagged as `MustSupport` within a profile, an instance can be provided that demonstrates the server's ability to expose data in that form. The theory is that if it can be demonstrated on at least one resource, then that proves that the system supports it.

To generate these specific tests, run `bundle exec bin/testscript_generator mustSupport`

### Process
- Unzips, processes, and stores the IG(s) contained within the `/igs` directory
- Identifies all resource profiles and the `MustSupport` elements within it
- Instantiates a template TestScript instance that contains the basic outline of the test, including a input variable for the target instance, a read of that instance, a check for profile conformance, and a check that the target element is populated in the way that must be supported.
- Adds additional details and checks, such as ancestor checks, referenced resource validation, and others
- Writes out to files, organized by profile

#### Relevant Code

Uses the template approach under the [templates](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator/templates) directory:
- [must_support_element_template.rb](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator/templates/must_support_element_template.rb): complex must support generation logic than includes some direct building of TestScript details
- [must_support_element_template.json](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator/templates/must_support_element_template.json): base template for an individual must support test
- [not_implemented_template.json](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator/templates/not_implemented_template.json): base template to use when a generation feature is not implemented. This means there are tests for each must support element, but some will just fail.

#### Current Status

These tests are a solid work in progress. They will work for many common MustSupport patterns, including choice types, some slices. They don't currently generate tests for complex or nested slices and have trouble with multiple response References and cases where multiple profiles are allowed. In addition, the need to provide a specific instance id for each test means that they aren't currently practical to use. Recently added support for subtest execution in the engine may support completing unimplemented cases and improving the use experience.

### Base Search Parameter Tests

Search Parameter tests check that a server supports searching using specific criteria. The tests currently generated focus on cross-resource parameters that can be used on any resource type.

To generate these specific tests, run `bundle exec bin/testscript_generator search`

#### Process

- Unzips, processes, and stores the IG(s) contained within the `/igs` directory
- Pulls out SearchParameter details from the base FHIR cross-resource definitions
- For each resource type used by a profile in the IG, creates a test that performs a search using each search parameter
- Writes the generated tests out, organizing them by search parameter

#### Relevant Code

Under the [generators](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator/generators) directory:
- [search_param_generator.rb](https://github.com/fhir-crucible/testscript-generator/blob/main/lib/testscript_generator/generators/search_param_generator.rb): search parameter test generation logic, leveraging the base [generator.rb](https://github.com/fhir-crucible/testscript-generator/blob/main/lib/testscript_generator/generators/generator.rb) class and coordinating with the blueprint_builder and other inputs.
- [base_searchparameters.json](https://github.com/fhir-crucible/testscript-generator/blob/main/lib/testscript_generator/generators/base_searchparameters.json): FHIR Bundle instance with SearchParameter instances for all the FHIR base search parameters supported on all resource types.
- [blueprint_builder.rb](https://github.com/fhir-crucible/testscript-generator/blob/main/lib/testscript_generator/generators/blueprint_builder.rb): logic for building up internal test representations
- [testscript_builder.rb](https://github.com/fhir-crucible/testscript-generator/blob/main/lib/testscript_generator/generators/testscript_builder.rb): logic for turning the internal test representations into TestScript instances

#### Current Status

These generated tests currently will not execute and represent a rough idea about how search parameters could be tested. Additional work needed to
- identify examples in the IG to use as fixtures
- define the specific checks that are needed following the search
- clarify when support for these search parameters is actually required

### Interaction Tests

Interaction tests are designed to check whether a server supports the API interactions required by the IG, such as the ability to create, update, read, and search for resource instances.

To generate these specific tests, run `bundle exec bin/testscript_generator interaction`

#### Process

- Unzips, processes, and stores the IG(s) contained within the `/igs` directory
- For each stored IG, extracts the resource-level interactions outlined in the server-side Capability Statement, e.g. `read`, `write`, `search`
- Filters those interactions by conformance level (i.e. **SHALL**, **SHOULD**, **MAY**) and creates tests organized by their level of conformance
- Writes the generated tests out, organizing them by their related conformance level

Currently, generated TestScripts test one resource-level interactions on individual resource types (*e.g.*, read an AllergyIntolerance or create a Patient).

#### Relevant Code

Under the [testscript_generator](https://github.com/fhir-crucible/testscript-generator/tree/main/lib/testscript_generator) directory
- [workflow_builder.rb](https://github.com/fhir-crucible/testscript-generator/blob/main/lib/testscript_generator/workflow_builder.rb): logic for building up internal test representations from CapabilityStatement instances
- [testscript_builder.rb](https://github.com/fhir-crucible/testscript-generator/blob/main/lib/testscript_generator/testscript_builder.rb): logic for turning the internal test representations into TestScript instances

#### Current Status

These generated tests currently will not execute and represent a rough idea about how interactions could be tested. Additional work needed to
- identify examples in the IG to use as fixtures
- define the specific checks that are needed

## Running the Generator

**Commands:**
  - `bundle install`
    - Functionality
      - This installs the dependencies specified in the Gemfile, allowing the generator to run.
  - `bundle exec bin/testscript_generator [parameters]`
    - Functionality
      - This runs the generator. It creates TestScripts that test the supported CRUDS interactions, as specified by the IG(s).
    - Parameters
      - `ig_directory=[path]`: overrides the default ig directory, which is `./igs`
      - `output_path=[path]`: overrides the default output directory, which is `./generated_testscripts`
      - `[type]`: specifies a specific test type to generate. If none are provided, then all types are generated. If one or more are provided, then only those specified types are generated. See above for the supported types.
    - Input
        - The IG(s) to be used for generation should be in `.tgz` or `.zip ` form and pointed to by the optional `ig_directory=` command-line argument.

## Future Directions

- [ ] Explore TestScript generation using alternative inputs
    - ExampleScenario Resources
- [ ] Increase variety in how TestScript generation is organized
    - Instead of generating/storing by conformance level, generate by interaction type or by resource
- [x] Command-line option for pipeline between TestScript Generator and TestScript Engine
- [ ] Generating tests that verify multi-system interactions

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