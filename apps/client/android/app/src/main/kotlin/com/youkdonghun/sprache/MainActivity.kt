package com.youkdonghun.sprache

import android.accounts.Account
import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.Scopes
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.FileNotFoundException
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingLocalDirectoryResult: MethodChannel.Result? = null
    private val localStorageExecutor = Executors.newSingleThreadExecutor()
    private val localStorageOperationInProgress = AtomicBoolean(false)

    private val authorizationLauncher =
        registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { activityResult ->
            val result = pendingResult ?: return@registerForActivityResult
            pendingResult = null

            if (activityResult.resultCode != Activity.RESULT_OK) {
                result.error("picker_cancelled", "Google Drive folder selection was cancelled", null)
                return@registerForActivityResult
            }

            try {
                val authorizationResult =
                    Identity.getAuthorizationClient(this)
                        .getAuthorizationResultFromIntent(activityResult.data)
                completeAuthorization(authorizationResult, result)
            } catch (exception: ApiException) {
                result.error(
                    "authorization_failed",
                    exception.localizedMessage ?: "Google Drive authorization failed",
                    exception.statusCode,
                )
            }
        }

    private val localDirectoryLauncher =
        registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { treeUri ->
            val result = pendingLocalDirectoryResult ?: return@registerForActivityResult
            pendingLocalDirectoryResult = null

            if (treeUri == null) {
                localStorageOperationInProgress.set(false)
                result.success(null)
                return@registerForActivityResult
            }

            runLockedLocalStorageOperation(result) {
                persistDirectoryPermission(treeUri)
                val root = requireTreeRoot(treeUri)
                mapOf(
                    "locationId" to treeUri.toString(),
                    "displayName" to readableName(root),
                )
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GOOGLE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "authorizeDrivePicker" -> {
                    val email = call.argument<String>("email")
                    if (email.isNullOrBlank()) {
                        result.error("missing_account", "A Google account email is required", null)
                    } else {
                        authorizeDrivePicker(email, result)
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCAL_STORAGE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDirectory" -> pickLocalDirectory(result)
                "verifyDirectory" ->
                    runLocalStorageOperation(result) {
                        val treeUri = requireLocationId(call)
                        requirePersistedPermission(treeUri, requireWrite = true)
                        val directory = resolveSpracheDirectory(treeUri)
                        verifyDirectoryReadWrite(directory.document)
                        mapOf("displayName" to directory.displayName)
                    }

                "writeBundle" ->
                    runLocalStorageOperation(result) {
                        writeBundle(call)
                    }

                "readLatestArchive" ->
                    runLocalStorageOperation(result) {
                        val treeUri = requireLocationId(call)
                        requirePersistedPermission(treeUri, requireWrite = false)
                        val directory = resolveSpracheDirectory(treeUri, createIfMissing = false)
                        readLatestArchive(directory.document)
                    }

                "hasLatestArchive" ->
                    runLocalStorageOperation(result) {
                        val treeUri = requireLocationId(call)
                        requirePersistedPermission(treeUri, requireWrite = false)
                        val directory =
                            resolveSpracheDirectoryOrNull(treeUri)
                                ?: return@runLocalStorageOperation false
                        readLatestArchive(directory.document) != null
                    }

                "archiveImport" ->
                    runLocalStorageOperation(result) {
                        archiveImport(call)
                    }

                "releaseDirectory" ->
                    runLocalStorageOperation(result) {
                        val treeUri = requireLocationId(call)
                        releaseDirectoryPermission(treeUri)
                        true
                    }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        localStorageExecutor.shutdown()
        super.onDestroy()
    }

    private fun pickLocalDirectory(result: MethodChannel.Result) {
        if (!localStorageOperationInProgress.compareAndSet(false, true)) {
            result.error(
                "storage_busy",
                "Another local storage operation is already in progress",
                null,
            )
            return
        }

        pendingLocalDirectoryResult = result
        try {
            localDirectoryLauncher.launch(null)
        } catch (exception: Exception) {
            pendingLocalDirectoryResult = null
            localStorageOperationInProgress.set(false)
            result.error(
                "directory_picker_failed",
                exception.localizedMessage ?: "Could not open the local folder picker",
                null,
            )
        }
    }

    private fun runLocalStorageOperation(
        result: MethodChannel.Result,
        operation: () -> Any?,
    ) {
        if (!localStorageOperationInProgress.compareAndSet(false, true)) {
            result.error(
                "storage_busy",
                "Another local storage operation is already in progress",
                null,
            )
            return
        }
        runLockedLocalStorageOperation(result, operation)
    }

    private fun runLockedLocalStorageOperation(
        result: MethodChannel.Result,
        operation: () -> Any?,
    ) {
        localStorageExecutor.execute {
            try {
                val value = operation()
                runOnUiThread {
                    localStorageOperationInProgress.set(false)
                    result.success(value)
                }
            } catch (exception: Exception) {
                val localStorageException =
                    exception as? LocalStorageException
                        ?: LocalStorageException(
                            "local_storage_failed",
                            exception.localizedMessage ?: "Local storage operation failed",
                            exception,
                        )
                runOnUiThread {
                    localStorageOperationInProgress.set(false)
                    result.error(
                        localStorageException.code,
                        localStorageException.message,
                        null,
                    )
                }
            }
        }
    }

    private fun requireLocationId(call: MethodCall): Uri {
        val locationId = call.argument<String>("locationId")
        if (locationId.isNullOrBlank()) {
            throw LocalStorageException(
                "missing_location",
                "A local storage location is required",
            )
        }
        return try {
            Uri.parse(locationId)
        } catch (exception: Exception) {
            throw LocalStorageException(
                "invalid_location",
                "The local storage location is invalid",
                exception,
            )
        }
    }

    private fun persistDirectoryPermission(treeUri: Uri) {
        val permissionFlags =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        try {
            contentResolver.takePersistableUriPermission(treeUri, permissionFlags)
        } catch (exception: SecurityException) {
            throw LocalStorageException(
                "directory_permission_failed",
                "The selected folder did not grant persistent read and write access",
                exception,
            )
        }
        requirePersistedPermission(treeUri, requireWrite = true)
    }

    private fun requirePersistedPermission(
        treeUri: Uri,
        requireWrite: Boolean,
    ) {
        val permission =
            contentResolver.persistedUriPermissions.firstOrNull { it.uri == treeUri }
                ?: throw LocalStorageException(
                    "directory_permission_missing",
                    "Access to the selected folder is no longer available",
                )
        if (!permission.isReadPermission || (requireWrite && !permission.isWritePermission)) {
            throw LocalStorageException(
                "directory_permission_missing",
                "The selected folder no longer has the required access permission",
            )
        }
    }

    private fun releaseDirectoryPermission(treeUri: Uri) {
        val permission =
            contentResolver.persistedUriPermissions.firstOrNull { it.uri == treeUri }
                ?: return
        var permissionFlags = 0
        if (permission.isReadPermission) {
            permissionFlags = permissionFlags or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        if (permission.isWritePermission) {
            permissionFlags = permissionFlags or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        }
        if (permissionFlags == 0) {
            return
        }
        try {
            contentResolver.releasePersistableUriPermission(treeUri, permissionFlags)
        } catch (_: SecurityException) {
            // The provider may already have revoked the grant. Releasing is best effort.
        }
    }

    private fun requireTreeRoot(treeUri: Uri): DocumentFile {
        val root = DocumentFile.fromTreeUri(this, treeUri)
        if (root == null || !root.exists() || !root.isDirectory) {
            throw LocalStorageException(
                "directory_unavailable",
                "The selected folder is not available",
            )
        }
        return root
    }

    private fun resolveSpracheDirectory(
        treeUri: Uri,
        createIfMissing: Boolean = true,
    ): StorageDirectory {
        return resolveSpracheDirectoryOrNull(treeUri, createIfMissing)
            ?: throw LocalStorageException(
                "directory_unavailable",
                "The Sprache storage folder is not available",
            )
    }

    private fun resolveSpracheDirectoryOrNull(
        treeUri: Uri,
        createIfMissing: Boolean = false,
    ): StorageDirectory? {
        val root = requireTreeRoot(treeUri)
        val rootName = readableName(root)
        if (rootName.equals(STORAGE_DIRECTORY_NAME, ignoreCase = true)) {
            return StorageDirectory(root, rootName)
        }

        val existing = root.findFile(STORAGE_DIRECTORY_NAME)
        if (existing != null) {
            if (!existing.isDirectory) {
                throw LocalStorageException(
                    "directory_conflict",
                    "A file named Sprache already exists in the selected folder",
                )
            }
            return StorageDirectory(
                existing,
                "$rootName/$STORAGE_DIRECTORY_NAME",
            )
        }
        if (!createIfMissing) {
            return null
        }

        val created =
            root.createDirectory(STORAGE_DIRECTORY_NAME)
                ?: throw LocalStorageException(
                    "directory_create_failed",
                    "Could not create the Sprache folder in the selected location",
                )
        return StorageDirectory(
            created,
            "$rootName/$STORAGE_DIRECTORY_NAME",
        )
    }

    private fun readableName(document: DocumentFile): String {
        return document.name?.takeIf(String::isNotBlank) ?: STORAGE_DIRECTORY_NAME
    }

    private fun verifyDirectoryReadWrite(directory: DocumentFile) {
        val probeName = ".sprache-probe-${UUID.randomUUID()}.tmp"
        val probeBytes = "Sprache local storage probe".toByteArray(Charsets.UTF_8)
        val probe =
            directory.createFile("application/octet-stream", probeName)
                ?: throw LocalStorageException(
                    "directory_write_failed",
                    "Could not write to the selected folder",
                )
        try {
            writeDocument(probe, probeBytes)
            val readBack = readDocument(probe)
            if (!readBack.contentEquals(probeBytes)) {
                throw LocalStorageException(
                    "directory_read_failed",
                    "The selected folder did not preserve the verification file",
                )
            }
        } finally {
            probe.delete()
        }
    }

    private fun writeBundle(call: MethodCall): Map<String, Any> {
        val treeUri = requireLocationId(call)
        requirePersistedPermission(treeUri, requireWrite = true)
        val directory = resolveSpracheDirectory(treeUri)
        val rawFiles =
            call.argument<List<Map<String, Any?>>>("files")
                ?: throw LocalStorageException(
                    "missing_files",
                    "A local storage bundle must contain files",
                )
        val manifestBytes =
            call.argument<ByteArray>("manifestBytes")
                ?: throw LocalStorageException(
                    "missing_manifest",
                    "A local storage bundle must contain a manifest",
                )
        val rawKeepRelativePaths =
            call.argument<List<String>>("keepRelativePaths").orEmpty()

        try {
            JSONObject(manifestBytes.toString(Charsets.UTF_8))
        } catch (exception: Exception) {
            throw LocalStorageException(
                "invalid_manifest",
                "The local storage manifest is not valid JSON",
                exception,
            )
        }

        val bundleFiles =
            rawFiles.mapIndexed { index, rawFile ->
                val relativePath =
                    rawFile["relativePath"] as? String
                        ?: throw LocalStorageException(
                            "invalid_bundle_file",
                            "Bundle file $index has no relative path",
                        )
                val bytes =
                    rawFile["bytes"] as? ByteArray
                        ?: throw LocalStorageException(
                            "invalid_bundle_file",
                            "Bundle file $index has no byte content",
                        )
                val expectedSha256 =
                    normalizeSha256(rawFile["sha256"] as? String)
                val safePath = validateRelativePath(relativePath)
                verifyInputDigest(bytes, expectedSha256)
                BundleFile(safePath, bytes, expectedSha256)
            }

        val keepRelativePaths =
            buildSet {
                rawKeepRelativePaths.forEach { add(validateRelativePath(it).normalized) }
                bundleFiles.forEach { add(it.relativePath.normalized) }
                add(MANIFEST_FILE_NAME)
                add(PREVIOUS_MANIFEST_FILE_NAME)
            }

        bundleFiles.forEach { bundleFile ->
            writeVerifiedFile(
                directory.document,
                bundleFile.relativePath,
                bundleFile.bytes,
                bundleFile.sha256,
            )
        }

        commitManifest(directory.document, manifestBytes)
        val committedKeepRelativePaths =
            runCatching {
                buildSet {
                    addAll(keepRelativePaths)
                    addAll(
                        referencedPathsFromManifest(
                            directory.document,
                            MANIFEST_FILE_NAME,
                        ),
                    )
                    addAll(
                        referencedPathsFromManifest(
                            directory.document,
                            PREVIOUS_MANIFEST_FILE_NAME,
                        ),
                    )
                }
            }.getOrNull()
        if (committedKeepRelativePaths != null) {
            pruneOldJsonFiles(
                directory = directory.document,
                relativePrefix = "",
                keepRelativePaths = committedKeepRelativePaths,
            )
        }

        return mapOf(
            "displayName" to directory.displayName,
            "writtenFiles" to bundleFiles.size,
        )
    }

    private fun archiveImport(call: MethodCall): Map<String, Any> {
        val treeUri = requireLocationId(call)
        requirePersistedPermission(treeUri, requireWrite = true)
        val directory = resolveSpracheDirectory(treeUri)
        val fileName =
            call.argument<String>("fileName")
                ?: throw LocalStorageException(
                    "missing_file_name",
                    "An import file name is required",
                )
        val bytes =
            call.argument<ByteArray>("bytes")
                ?: throw LocalStorageException(
                    "missing_file_bytes",
                    "Import file content is required",
                )
        val expectedSha256 = normalizeSha256(call.argument<String>("sha256"))
        verifyInputDigest(bytes, expectedSha256)

        val importsDirectory = ensureDirectory(directory.document, IMPORTS_DIRECTORY_NAME)
        val safeName = sanitizeImportName(fileName)
        val digestPrefix = expectedSha256.take(12)
        var relativePath = "$IMPORTS_DIRECTORY_NAME/$digestPrefix-$safeName"
        var targetName = relativePath.substringAfterLast('/')
        var target = importsDirectory.findFile(targetName)

        if (target != null && target.isFile) {
            val digest = digestDocument(target)
            if (digest.sha256 == expectedSha256 && digest.bytes == bytes.size.toLong()) {
                return mapOf(
                    "created" to false,
                    "relativePath" to relativePath,
                )
            }
        }

        var suffix = 2
        while (target != null) {
            targetName = "$digestPrefix-$suffix-$safeName"
            relativePath = "$IMPORTS_DIRECTORY_NAME/$targetName"
            target = importsDirectory.findFile(targetName)
            suffix += 1
        }

        val created =
            importsDirectory.createFile(mimeTypeFor(targetName), targetName)
                ?: throw LocalStorageException(
                    "file_create_failed",
                    "Could not create the local import archive",
                )
        try {
            writeDocument(created, bytes)
            verifyDocumentDigest(created, expectedSha256, bytes.size.toLong())
        } catch (exception: Exception) {
            created.delete()
            throw exception
        }

        return mapOf(
            "created" to true,
            "relativePath" to relativePath,
        )
    }

    private fun readLatestArchive(directory: DocumentFile): ByteArray? {
        var lastFailure: LocalStorageException? = null
        for (manifestName in listOf(MANIFEST_FILE_NAME, PREVIOUS_MANIFEST_FILE_NAME)) {
            val manifest = directory.findFile(manifestName) ?: continue
            try {
                val archive = readArchiveFromManifest(directory, manifest)
                if (archive != null) {
                    return archive
                }
            } catch (exception: LocalStorageException) {
                lastFailure = exception
            }
        }
        if (lastFailure != null) {
            throw lastFailure
        }
        return null
    }

    private fun readArchiveFromManifest(
        directory: DocumentFile,
        manifest: DocumentFile,
    ): ByteArray? {
        if (!manifest.isFile) {
            throw LocalStorageException(
                "invalid_manifest",
                "The local storage manifest is not a file",
            )
        }
        val manifestJson =
            try {
                JSONObject(readDocument(manifest).toString(Charsets.UTF_8))
            } catch (exception: Exception) {
                throw LocalStorageException(
                    "invalid_manifest",
                    "The local storage manifest could not be read",
                    exception,
                )
            }
        val files =
            manifestJson.optJSONObject("files")
                ?: throw LocalStorageException(
                    "invalid_manifest",
                    "The local storage manifest has no file index",
                )
        val latest = files.optJSONObject(LATEST_ARCHIVE_KEY) ?: return null
        val relativePathValue = latest.optString("relativePath")
        if (relativePathValue.isBlank()) {
            throw LocalStorageException(
                "invalid_manifest",
                "The latest archive entry has no relative path",
            )
        }
        val expectedSha256 = normalizeSha256(latest.optString("sha256"))
        val expectedBytes =
            when {
                latest.has("bytes") -> latest.optLong("bytes", -1)
                latest.has("byteLength") -> latest.optLong("byteLength", -1)
                else -> -1
            }
        if (expectedBytes < 0) {
            throw LocalStorageException(
                "invalid_manifest",
                "The latest archive entry has no valid byte count",
            )
        }

        val relativePath = validateRelativePath(relativePathValue)
        val archive =
            findFile(directory, relativePath)
                ?: throw LocalStorageException(
                    "archive_not_found",
                    "The latest local Sprache archive is missing",
                )
        if (!archive.isFile) {
            throw LocalStorageException(
                "archive_not_found",
                "The latest local Sprache archive is not a file",
            )
        }
        val archiveBytes = readDocument(archive)
        if (archiveBytes.size.toLong() != expectedBytes ||
            sha256(archiveBytes) != expectedSha256
        ) {
            throw LocalStorageException(
                "integrity_failed",
                "The latest local Sprache archive failed its integrity check",
            )
        }
        return archiveBytes
    }

    private fun writeVerifiedFile(
        root: DocumentFile,
        relativePath: SafeRelativePath,
        bytes: ByteArray,
        expectedSha256: String,
    ) {
        var parent = root
        relativePath.segments.dropLast(1).forEach { segment ->
            parent = ensureDirectory(parent, segment)
        }
        val name = relativePath.segments.last()
        var file = parent.findFile(name)
        if (file != null) {
            if (!file.isFile) {
                throw LocalStorageException(
                    "file_conflict",
                    "A folder already exists at ${relativePath.normalized}",
                )
            }
            val existingDigest = digestDocument(file)
            if (existingDigest.sha256 == expectedSha256 &&
                existingDigest.bytes == bytes.size.toLong()
            ) {
                return
            }
            if (!file.delete()) {
                throw LocalStorageException(
                    "file_replace_failed",
                    "Could not replace ${relativePath.normalized}",
                )
            }
            file = null
        }
        file =
            parent.createFile(mimeTypeFor(name), name)
                ?: throw LocalStorageException(
                    "file_create_failed",
                    "Could not create ${relativePath.normalized}",
                )
        try {
            writeDocument(file, bytes)
            verifyDocumentDigest(file, expectedSha256, bytes.size.toLong())
        } catch (exception: Exception) {
            file.delete()
            throw exception
        }
    }

    private fun commitManifest(
        directory: DocumentFile,
        manifestBytes: ByteArray,
    ) {
        directory.findFile(NEXT_MANIFEST_FILE_NAME)?.let { next ->
            if (!next.delete()) {
                throw LocalStorageException(
                    "manifest_commit_failed",
                    "Could not clear an unfinished local storage manifest",
                )
            }
        }
        val nextManifest =
            directory.createFile("application/json", NEXT_MANIFEST_FILE_NAME)
                ?: throw LocalStorageException(
                    "manifest_commit_failed",
                    "Could not stage the local storage manifest",
                )
        try {
            writeDocument(nextManifest, manifestBytes)
            val stagedBytes = readDocument(nextManifest)
            if (!stagedBytes.contentEquals(manifestBytes)) {
                throw LocalStorageException(
                    "manifest_commit_failed",
                    "The staged local storage manifest failed verification",
                )
            }
        } catch (exception: Exception) {
            nextManifest.delete()
            throw exception
        }

        val currentManifest = directory.findFile(MANIFEST_FILE_NAME)
        val previousManifest = directory.findFile(PREVIOUS_MANIFEST_FILE_NAME)
        val previousCurrentBytes =
            currentManifest?.takeIf(DocumentFile::isFile)?.let(::readDocument)

        if (previousManifest != null && !previousManifest.delete()) {
            nextManifest.delete()
            throw LocalStorageException(
                "manifest_commit_failed",
                "Could not rotate the previous local storage manifest",
            )
        }

        try {
            if (currentManifest != null) {
                if (!currentManifest.isFile ||
                    !currentManifest.renameTo(PREVIOUS_MANIFEST_FILE_NAME)
                ) {
                    throw LocalStorageException(
                        "manifest_commit_failed",
                        "Could not preserve the current local storage manifest",
                    )
                }
            }
            if (!nextManifest.renameTo(MANIFEST_FILE_NAME)) {
                throw LocalStorageException(
                    "manifest_commit_failed",
                    "Could not commit the new local storage manifest",
                )
            }
            val committed =
                directory.findFile(MANIFEST_FILE_NAME)
                    ?: throw LocalStorageException(
                        "manifest_commit_failed",
                        "The committed local storage manifest is missing",
                    )
            if (!readDocument(committed).contentEquals(manifestBytes)) {
                throw LocalStorageException(
                    "manifest_commit_failed",
                    "The committed local storage manifest failed verification",
                )
            }
        } catch (exception: Exception) {
            restorePreviousManifest(directory, previousCurrentBytes)
            throw if (exception is LocalStorageException) {
                exception
            } else {
                LocalStorageException(
                    "manifest_commit_failed",
                    exception.localizedMessage ?: "Could not commit the local storage manifest",
                    exception,
                )
            }
        }
    }

    private fun restorePreviousManifest(
        directory: DocumentFile,
        previousCurrentBytes: ByteArray?,
    ) {
        directory.findFile(NEXT_MANIFEST_FILE_NAME)?.delete()
        directory.findFile(MANIFEST_FILE_NAME)?.delete()
        if (previousCurrentBytes == null) {
            return
        }
        val rotated = directory.findFile(PREVIOUS_MANIFEST_FILE_NAME)
        if (rotated != null && rotated.isFile && rotated.renameTo(MANIFEST_FILE_NAME)) {
            return
        }
        directory.findFile(MANIFEST_FILE_NAME)?.delete()
        val restored =
            directory.createFile("application/json", MANIFEST_FILE_NAME)
                ?: return
        try {
            writeDocument(restored, previousCurrentBytes)
        } catch (_: Exception) {
            restored.delete()
        }
    }

    private fun pruneOldJsonFiles(
        directory: DocumentFile,
        relativePrefix: String,
        keepRelativePaths: Set<String>,
    ) {
        try {
            directory.listFiles().forEach { child ->
                val name = child.name ?: return@forEach
                val relativePath =
                    if (relativePrefix.isEmpty()) {
                        name
                    } else {
                        "$relativePrefix/$name"
                    }
                if (child.isDirectory) {
                    if (relativePath != IMPORTS_DIRECTORY_NAME) {
                        pruneOldJsonFiles(child, relativePath, keepRelativePaths)
                    }
                } else if (
                    name.endsWith(".json", ignoreCase = true) &&
                    relativePath !in keepRelativePaths
                ) {
                    child.delete()
                }
            }
        } catch (_: Exception) {
            // Old generation cleanup is intentionally best effort.
        }
    }

    private fun referencedPathsFromManifest(
        directory: DocumentFile,
        manifestName: String,
    ): Set<String> {
        val manifest = directory.findFile(manifestName)
            ?.takeIf(DocumentFile::isFile)
            ?: return emptySet()
        return try {
            val manifestJson = JSONObject(readDocument(manifest).toString(Charsets.UTF_8))
            val files =
                manifestJson.optJSONObject("files")
                    ?: throw LocalStorageException(
                        "manifest_cleanup_skipped",
                        "Retained local storage manifest has no valid files map",
                    )
            buildSet {
                val keys = files.keys()
                while (keys.hasNext()) {
                    val entry =
                        files.optJSONObject(keys.next())
                            ?: throw LocalStorageException(
                                "manifest_cleanup_skipped",
                                "Retained local storage manifest has an invalid file entry",
                            )
                    val relativePath = entry.optString("relativePath")
                    if (relativePath.isBlank()) {
                        throw LocalStorageException(
                            "manifest_cleanup_skipped",
                            "Retained local storage manifest has an empty file path",
                        )
                    }
                    add(validateRelativePath(relativePath).normalized)
                }
            }
        } catch (exception: Exception) {
            throw LocalStorageException(
                "manifest_cleanup_skipped",
                "Could not verify a retained local storage manifest",
                exception,
            )
        }
    }

    private fun ensureDirectory(
        parent: DocumentFile,
        name: String,
    ): DocumentFile {
        val existing = parent.findFile(name)
        if (existing != null) {
            if (!existing.isDirectory) {
                throw LocalStorageException(
                    "directory_conflict",
                    "A file already exists where folder $name is required",
                )
            }
            return existing
        }
        return parent.createDirectory(name)
            ?: throw LocalStorageException(
                "directory_create_failed",
                "Could not create folder $name",
            )
    }

    private fun findFile(
        root: DocumentFile,
        relativePath: SafeRelativePath,
    ): DocumentFile? {
        var current = root
        relativePath.segments.forEachIndexed { index, segment ->
            val child = current.findFile(segment) ?: return null
            if (index < relativePath.segments.lastIndex && !child.isDirectory) {
                return null
            }
            current = child
        }
        return current
    }

    private fun writeDocument(
        document: DocumentFile,
        bytes: ByteArray,
    ) {
        val output =
            try {
                contentResolver.openOutputStream(document.uri, "wt")
            } catch (_: FileNotFoundException) {
                contentResolver.openOutputStream(document.uri, "w")
            }
        if (output == null) {
            throw LocalStorageException(
                "file_write_failed",
                "Could not open ${readableName(document)} for writing",
            )
        }
        try {
            output.use {
                it.write(bytes)
                it.flush()
            }
        } catch (exception: Exception) {
            throw LocalStorageException(
                "file_write_failed",
                "Could not write ${readableName(document)}",
                exception,
            )
        }
    }

    private fun readDocument(document: DocumentFile): ByteArray {
        val input =
            contentResolver.openInputStream(document.uri)
                ?: throw LocalStorageException(
                    "file_read_failed",
                    "Could not open ${readableName(document)} for reading",
                )
        return try {
            input.use { it.readBytes() }
        } catch (exception: Exception) {
            throw LocalStorageException(
                "file_read_failed",
                "Could not read ${readableName(document)}",
                exception,
            )
        }
    }

    private fun digestDocument(document: DocumentFile): DocumentDigest {
        val digest = MessageDigest.getInstance("SHA-256")
        var byteCount = 0L
        val input =
            contentResolver.openInputStream(document.uri)
                ?: throw LocalStorageException(
                    "file_read_failed",
                    "Could not open ${readableName(document)} for verification",
                )
        try {
            input.use { stream ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = stream.read(buffer)
                    if (read < 0) {
                        break
                    }
                    if (read == 0) {
                        continue
                    }
                    digest.update(buffer, 0, read)
                    byteCount += read
                }
            }
        } catch (exception: Exception) {
            throw LocalStorageException(
                "file_read_failed",
                "Could not verify ${readableName(document)}",
                exception,
            )
        }
        return DocumentDigest(digest.digest().toHex(), byteCount)
    }

    private fun verifyDocumentDigest(
        document: DocumentFile,
        expectedSha256: String,
        expectedBytes: Long,
    ) {
        val digest = digestDocument(document)
        if (digest.sha256 != expectedSha256 || digest.bytes != expectedBytes) {
            throw LocalStorageException(
                "integrity_failed",
                "${readableName(document)} failed its integrity check",
            )
        }
    }

    private fun verifyInputDigest(
        bytes: ByteArray,
        expectedSha256: String,
    ) {
        if (sha256(bytes) != expectedSha256) {
            throw LocalStorageException(
                "integrity_failed",
                "The provided file content does not match its SHA-256 value",
            )
        }
    }

    private fun normalizeSha256(value: String?): String {
        val normalized = value?.trim()?.lowercase().orEmpty()
        if (!SHA256_PATTERN.matches(normalized)) {
            throw LocalStorageException(
                "invalid_sha256",
                "A valid SHA-256 value is required",
            )
        }
        return normalized
    }

    private fun sha256(bytes: ByteArray): String {
        return MessageDigest.getInstance("SHA-256").digest(bytes).toHex()
    }

    private fun ByteArray.toHex(): String {
        return joinToString(separator = "") { byte ->
            (byte.toInt() and 0xff).toString(16).padStart(2, '0')
        }
    }

    private fun validateRelativePath(value: String): SafeRelativePath {
        if (value.isBlank() ||
            value != value.trim() ||
            value.startsWith("/") ||
            value.startsWith("\\") ||
            value.contains('\\') ||
            WINDOWS_ABSOLUTE_PATH_PATTERN.containsMatchIn(value)
        ) {
            throw LocalStorageException(
                "invalid_relative_path",
                "Local storage paths must be safe relative paths",
            )
        }
        val segments = value.split('/')
        if (segments.any { segment ->
                segment.isBlank() ||
                    segment == "." ||
                    segment == ".." ||
                    segment.any(Char::isISOControl)
            }
        ) {
            throw LocalStorageException(
                "invalid_relative_path",
                "Local storage paths must not contain traversal or empty segments",
            )
        }
        return SafeRelativePath(segments.joinToString("/"), segments)
    }

    private fun sanitizeImportName(value: String): String {
        val baseName =
            value
                .replace('\\', '/')
                .substringAfterLast('/')
                .trim()
        val replaced =
            buildString {
                baseName.forEach { character ->
                    append(
                        if (character.isISOControl() ||
                            character in IMPORT_FILE_UNSAFE_CHARACTERS
                        ) {
                            '_'
                        } else {
                            character
                        },
                    )
                }
            }
                .trim()
                .trim('.')
                .replace(REPEATED_UNDERSCORE_PATTERN, "_")
        val safeName =
            replaced
                .ifBlank { DEFAULT_IMPORT_FILE_NAME }
                .take(MAX_IMPORT_FILE_NAME_LENGTH)
                .trimEnd('.', ' ')
                .ifBlank { DEFAULT_IMPORT_FILE_NAME }
        return safeName
    }

    private fun mimeTypeFor(fileName: String): String {
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "json" -> "application/json"
            "csv" -> "text/csv"
            "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            else -> "application/octet-stream"
        }
    }

    private fun authorizeDrivePicker(email: String, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("authorization_in_progress", "Google authorization is already in progress", null)
            return
        }

        val request =
            AuthorizationRequest.builder()
                .setAccount(Account(email, GOOGLE_ACCOUNT_TYPE))
                .setRequestedScopes(listOf(Scope(Scopes.DRIVE_FILE)))
                .setOptOutIncludingGrantedScopes(true)
                .setPrompt(AuthorizationRequest.Prompt.CONSENT)
                .addResourceParameter(
                    AuthorizationRequest.ResourceParameter.PICKER_OAUTH_TRIGGER,
                    "true",
                )
                .addResourceParameter(
                    AuthorizationRequest.ResourceParameter.PICKER_ALLOW_FOLDER_SELECTION,
                    "true",
                )
                .build()

        Identity.getAuthorizationClient(this)
            .authorize(request)
            .addOnSuccessListener { authorizationResult ->
                if (authorizationResult.hasResolution()) {
                    val pendingIntent = authorizationResult.pendingIntent
                    if (pendingIntent == null) {
                        result.error(
                            "missing_resolution",
                            "Google authorization did not provide a resolution",
                            null,
                        )
                        return@addOnSuccessListener
                    }
                    pendingResult = result
                    authorizationLauncher.launch(
                        IntentSenderRequest.Builder(pendingIntent.intentSender).build(),
                    )
                } else {
                    completeAuthorization(authorizationResult, result)
                }
            }
            .addOnFailureListener { exception ->
                result.error(
                    "authorization_failed",
                    exception.localizedMessage ?: "Google Drive authorization failed",
                    null,
                )
            }
    }

    private fun completeAuthorization(
        authorizationResult: AuthorizationResult,
        result: MethodChannel.Result,
    ) {
        val accessToken = authorizationResult.accessToken
        val pickedIds =
            authorizationResult.tokenResponseParams
                ?.getString(PICKED_FILE_IDS)
                ?.split(",")
                ?.map(String::trim)
                ?.filter(String::isNotEmpty)
                .orEmpty()

        if (accessToken.isNullOrBlank()) {
            result.error("missing_access_token", "Google did not return an access token", null)
            return
        }
        if (pickedIds.isEmpty()) {
            result.error("missing_folder", "Google Picker did not return a folder", null)
            return
        }

        result.success(
            mapOf(
                "accessToken" to accessToken,
                "folderId" to pickedIds.first(),
            ),
        )
    }

    companion object {
        private const val GOOGLE_CHANNEL = "com.youkdonghun.sprache/google"
        private const val LOCAL_STORAGE_CHANNEL = "com.youkdonghun.sprache/local_storage"
        private const val GOOGLE_ACCOUNT_TYPE = "com.google"
        private const val PICKED_FILE_IDS = "picked_file_ids"
        private const val STORAGE_DIRECTORY_NAME = "Sprache"
        private const val IMPORTS_DIRECTORY_NAME = "imports"
        private const val MANIFEST_FILE_NAME = "manifest.json"
        private const val NEXT_MANIFEST_FILE_NAME = "manifest.next.json"
        private const val PREVIOUS_MANIFEST_FILE_NAME = "manifest.previous.json"
        private const val LATEST_ARCHIVE_KEY = "backups/latest.json"
        private const val DEFAULT_IMPORT_FILE_NAME = "import.bin"
        private const val MAX_IMPORT_FILE_NAME_LENGTH = 120
        private const val IMPORT_FILE_UNSAFE_CHARACTERS = "<>:\"/\\|?*"
        private val SHA256_PATTERN = Regex("^[0-9a-f]{64}$")
        private val WINDOWS_ABSOLUTE_PATH_PATTERN = Regex("^[A-Za-z]:")
        private val REPEATED_UNDERSCORE_PATTERN = Regex("_+")
    }

    private data class StorageDirectory(
        val document: DocumentFile,
        val displayName: String,
    )

    private data class SafeRelativePath(
        val normalized: String,
        val segments: List<String>,
    )

    private data class BundleFile(
        val relativePath: SafeRelativePath,
        val bytes: ByteArray,
        val sha256: String,
    )

    private data class DocumentDigest(
        val sha256: String,
        val bytes: Long,
    )

    private class LocalStorageException(
        val code: String,
        message: String,
        cause: Throwable? = null,
    ) : Exception(message, cause)
}
