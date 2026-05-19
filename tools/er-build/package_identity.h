#ifndef ER_BUILD_PACKAGE_IDENTITY_H
#define ER_BUILD_PACKAGE_IDENTITY_H

/*
 * Purpose:
 *   Generate deterministic identity metadata for canonical app packages.
 * Intention:
 *   Keep app admission inputs explicit and content-addressed while er-build
 *   remains a small orchestration tool.
 */

int erb_write_app_package_identity(const char* identity_path,
                                   const char* app_source,
                                   const char* manifest_source,
                                   const char* output_wasm);
int erb_verify_app_package_identity(const char* identity_path,
                                    const char* app_source,
                                    const char* manifest_source,
                                    const char* output_wasm);

#endif
