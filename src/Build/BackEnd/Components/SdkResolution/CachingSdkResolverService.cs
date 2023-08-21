// Licensed to the .NET Foundation under one or more agreements.
// The .NET Foundation licenses this file to you under the MIT license.

using System;
using System.Collections.Concurrent;
using Microsoft.Build.BackEnd.Logging;
using Microsoft.Build.Collections;
using Microsoft.Build.Construction;
using Microsoft.Build.Eventing;
using Microsoft.Build.Framework;
using Microsoft.Build.Shared;

#nullable disable

namespace Microsoft.Build.BackEnd.SdkResolution
{
    internal sealed class CachingSdkResolverService : SdkResolverService
    {
        private static readonly ConcurrentDictionary<SdkReference, Lazy<SdkResult>> s_cache = new ConcurrentDictionary<SdkReference, Lazy<SdkResult>>();

        /// <summary>
        /// Stores the cache in a set of concurrent dictionaries.  The main dictionary is by build submission ID and the inner dictionary contains a case-insensitive SDK name and the cached <see cref="SdkResult"/>.
        /// </summary>
        private static readonly ConcurrentDictionary<int, ConcurrentDictionary<string, SdkResult>> _cache = new ConcurrentDictionary<int, ConcurrentDictionary<string, SdkResult>>();

        public override void ClearCache(int submissionId)
        {
            base.ClearCache(submissionId);

            _ = _cache.TryRemove(submissionId, out _);
        }

        public static void ClearCaches()
        {
            s_cache.Clear();
            _cache.Clear();
        }

        public override SdkResult ResolveSdk(int submissionId, SdkReference sdk, LoggingContext loggingContext, ElementLocation sdkReferenceLocation, string solutionPath, string projectPath, bool interactive, bool isRunningInVisualStudio, bool failOnUnresolvedSdk)
        {
            SdkResult result;

            bool wasResultCached = true;

            MSBuildEventSource.Log.CachedSdkResolverServiceResolveSdkStart(sdk.Name, solutionPath, projectPath);

            if (Traits.Instance.EscapeHatches.DisableSdkResolutionCache)
            {
                result = base.ResolveSdk(submissionId, sdk, loggingContext, sdkReferenceLocation, solutionPath, projectPath, interactive, isRunningInVisualStudio, failOnUnresolvedSdk);
            }
            else
            {
                // Get the dictionary for the specified submission if one is already added otherwise create a new dictionary for the submission.
                ConcurrentDictionary<string, SdkResult> cached = _cache.GetOrAdd(
                    submissionId,
                    _ => new ConcurrentDictionary<string, SdkResult>(MSBuildNameIgnoreCaseComparer.Default));

                // Try to get the submission-specific cached result first.
                result = cached.GetOrAdd(sdk.Name, _ =>
                {
                    /*
                     * Get a Lazy<SdkResult> if available, otherwise create a Lazy<SdkResult> which will resolve the SDK with the SdkResolverService.Instance.  If multiple projects are attempting to resolve
                     * the same SDK, they will all get back the same Lazy<SdkResult> which ensures that a single build submission resolves each unique SDK only one time.
                     */
                    Lazy<SdkResult> resultLazy = s_cache.GetOrAdd(
                        sdk,
                        key => new Lazy<SdkResult>(() =>
                        {
                            wasResultCached = false;

                            return base.ResolveSdk(submissionId, sdk, loggingContext, sdkReferenceLocation, solutionPath, projectPath, interactive, isRunningInVisualStudio, failOnUnresolvedSdk);
                        }));

                    // Get the lazy value which will block all waiting threads until the SDK is resolved at least once while subsequent calls get cached results.
                    return resultLazy.Value;
                });
            }

            if (result != null &&
                !IsReferenceSameVersion(sdk, result.SdkReference.Version) &&
                !IsReferenceSameVersion(sdk, result.Version))
            {
                // MSB4240: Multiple versions of the same SDK "{0}" cannot be specified. The previously resolved SDK version "{1}" from location "{2}" will be used and the version "{3}" will be ignored.
                loggingContext.LogWarning(null, new BuildEventFileInfo(sdkReferenceLocation), "ReferencingMultipleVersionsOfTheSameSdk", sdk.Name, result.Version, result.ElementLocation, sdk.Version);
            }

            MSBuildEventSource.Log.CachedSdkResolverServiceResolveSdkStop(sdk.Name, solutionPath, projectPath, result.Success, wasResultCached);

            return result;
        }
    }
}
