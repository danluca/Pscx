@{
    # Build/test-only dependencies. They are saved beneath .tools and are never
    # packaged.
    PesterVersion = '6.0.0'
    PSScriptAnalyzerVersion = '1.25.0'
    PlatyPSVersion = '1.0.1'

    # Conservative initial gates based on the Phase 2.2 smoke suites. Raise
    # these independently as tests migrate; never combine the percentages.
    ManagedCoverageMinimumPercent = 1
    PowerShellCoverageMinimumPercent = 5
}
