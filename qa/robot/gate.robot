*** Settings ***
Documentation     Verdant quality guarantees. Every test here is a claim the release makes,
...               executed against the real addon code through the offline ESO harness,
...               the SimLab oracle and the layout audit.
Library           VerdantGate.py

*** Test Cases ***
Every Lua File Parses
    [Tags]    static
    ${msg}=    Every Lua File Parses
    Log    ${msg}

Harness Passes With Diagnostics On
    [Tags]    harness
    ${msg}=    Harness Passes    1
    Log    ${msg}

Harness Passes In Release Mode
    [Tags]    harness
    ${msg}=    Harness Passes    0
    Log    ${msg}

Simulated Fights Match The Oracle
    [Documentation]    Three synthetic fights (trial boss, dungeon pull, burst) run through
    ...                the real pipeline; every metric must equal the oracle's independent
    ...                computation with zero error.
    [Tags]    oracle
    ${msg}=    Simlab Scenarios Pass
    Log    ${msg}

Mockups Render
    [Tags]    layout
    ${msg}=    Simlab Mockups Render
    Log    ${msg}

Layout Audit Is Clean
    [Documentation]    No text under a button, no overlapping labels, at default and minimum size.
    [Tags]    layout
    ${msg}=    Layout Audit Is Clean
    Log    ${msg}

Real Traces Replay Clean
    [Documentation]    Recorded in-game traces replay through the addon and pass the audit.
    [Tags]    replay
    ${msg}=    Replay Audits Are Clean
    Log    ${msg}

A Library Session Renders Exactly What Was Live
    [Documentation]    Every view rendered from a saved session is pixel-for-pixel the view
    ...                that was on screen when it was recorded.
    [Tags]    library
    ${msg}=    Live Equals Library
    Log    ${msg}
