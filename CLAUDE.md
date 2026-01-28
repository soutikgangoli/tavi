- Important Instruction Regarding Error Fixes:

   When addressing Xcode build errors or warnings, do not downgrade, deprecate, or remove any existing features or functionality. All fixes must:

   1. Preserve Functionality - Maintain the exact same capabilities and features that currently exist
   2. Maintain Feasibility - Keep all tools and features fully operational and usable
   3. Ensure Equal Usability - The user experience and feature accessibility must remain identical

   Fix the code, don't deprecate it. Errors should be resolved through proper implementation, not by removing or reducing features.

- Important Instruction Regarding Documentation Files:

   Do NOT create .md files unnecessarily. Only create documentation files when absolutely necessary, such as:

   1. Critical audits (crash reports, security issues, compilation blockers)
   2. Major project completion summaries
   3. Important architectural decisions that need to be preserved
   4. Essential documentation that will be referenced later

   Avoid creating .md files for:
   - Regular task completions
   - Minor fixes or updates
   - Status reports that can be communicated directly
   - Temporary information

   This helps reduce token consumption and keeps the project clean. Communicate results directly to the user instead of creating files.