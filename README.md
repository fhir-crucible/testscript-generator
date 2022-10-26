
# TestScript Generator

## Background and Overview

The TestScript Generator aims to ease the testing process by creating a complete suite of TestScripts to be leveraged against any FHIR endpoint that conforms to a given Implementation Guide (IG). *__The generator accomplishes this through several steps__*:

> - Unzips, processes, and stores the IG(s) contained within the `/igs` directory
>
> - For each stored IG, extracts the resource-level interactions outlined in the server-side Capability Statement
>
> - Filters those interactions by conformance level (i.e. **SHALL**, **SHOULD**, **MAY**) and creates tests organized by their level of conformance
>   - See the __*Generation Methodology*__ section for more information on how tests are created
> - Writes the generated tests out to the `/testscripts` directory, organizing them by their related conformance level


This generator is intended to be used in concert with the [TestScript Engine](https://github.com/fhir-crucible/testscript-engine): users can auto-create TestScripts with this generator and then execute them against endpoint(s) with the engine. The recommendation is to clone this repo, install the TestScript Engine gem, use this TestScript Generator to autogenerate tests, and then run the TestScript Engine executable.

## Generation Methodology

Currently, generated TestScripts test one resource-level interactions on individual resource types (*e.g.*, read an AllergyIntolerance or create a Patient).

## Future Directions

- [ ] Explore TestScript generation using alternative inputs
    - ExampleScenario Resources
- [ ] Increase variety in how TestScript generation is organized
    - Instead of generating/storing by conformance level, generate by interaction type or by resource
- [x] Command-line option for pipeline between TestScript Generator and TestScript Engine
- [ ] Generating tests that verify multi-system interactions

## Running the Generator

**Commands:**
  - `bundle install`
    - Functionality
      - This installs the dependencies specified in the Gemfile, allowing the generator to run. Run this command after downloading the repo and before running `ruby driver.rb` for the first time.
  - `bundle exec bin/testscript_generator [Optional: IG_DIRECTORY] [Optional: OUTPUT_DIRECTORY]`
    - Functionality
      - This runs the generator. It creates TestScripts that test the supported CRUDS interactions, as specified by the IG(s).
    - Input
        - The IG(s) to be used for generation should be in `.tgz` or `.zip ` form and pointed to by the optional `IG_DIRECTORY` command-line argument. To set an optional `OUTPUT_DIRECTORY`, the `IG_DIRECTORY` must also be specified.

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