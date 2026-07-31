# Managed test inventory

This inventory applies the ownership rules in Phase 2.2 of the modernization
plan. It records the intended destination of the pre-existing NUnit fixtures;
it does not claim that every migration has been completed.

## Retained in `Pscx.InternalTests`

| Fixture | Tests | Reason |
| --- | ---: | --- |
| `Time/DateTimeArithmeticTests.cs` | 14 | Pure date/time forwarding and transition logic |
| `SimpleUnits/LengthTests.cs` | 4 | Pure unit/value-object behavior |

## Retain after isolation from the legacy project

| Fixture | Tests | Required follow-up |
| --- | ---: | --- |
| `Database/DataTypeSetterTest.cs` | 2 | Move to a Windows-targeted internal test project |
| `Database/TypeBuilderTest.cs` | 3 | Move to a Windows-targeted internal test project |

## Migrate to packaged-module Pester tests

| Fixture | Tests | Public behavior |
| --- | ---: | --- |
| `Accelerators/Base64Test.cs` | 1 | Accelerator behavior in a PowerShell session |
| `DirectoryServices/DirectoryServicesTest.cs` | 1 | Windows provider behavior |
| `Drawing/ExportBitmapTest.cs` | 6 | Bitmap cmdlet behavior and files |
| `Drawing/ResizeBitmapTest.cs` | 3 | Bitmap cmdlet parameters and output |
| `GetHashCommandTests.cs` | 2 | Cmdlet parameters, pipeline input, and output |
| `IO/PscxLinkTests.cs` | 1 | Windows filesystem cmdlet integration |
| `IO/PscxPathInfoTests.cs` | 12 | `-Path`/`-LiteralPath` and wildcard binding |
| `SimpleUnits/ConvertToUnitTest.cs` | 1 | Cmdlet input and output contract |
| `Xml/TestXmlTests.cs` | 2 | Cmdlet behavior against real files |
| `Yaml/YamlTest.cs` | 1 | PowerShell conversion command behavior |

## Removed

| Fixture | Tests | Reason |
| --- | ---: | --- |
| `DirectoryServices/ForeignServerTests.cs` | 7 | Hard-coded, unreachable external lab dependencies made the fixture unsafe and non-reproducible |

Support classes such as `PscxCmdletTest`, `PscxProviderTest`, and
`Drawing/BitmapTestBase` remain only while their dependent fixtures are being
migrated. The legacy project is not part of the release-blocking unified test
run; `TestAll` remains available to expose its current failures during migration.
