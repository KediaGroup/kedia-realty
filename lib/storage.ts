export const projectImagesBucket = "project-images";
export const careerResumesBucket = "career-resumes";

// Mirrors allowed_mime_types on the project-images bucket. HEIC (iPhone/Mac
// default) is rejected by the bucket and most browsers cannot display it.
export const projectImageMimeTypes = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
];
export const projectImageAccept = projectImageMimeTypes.join(",");
export const unsupportedProjectImageMessage =
  "Only JPG, PNG, WebP or GIF images can be uploaded. Convert HEIC photos to JPG first.";

export function uniqueNonEmptyValues(values: string[]) {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean)));
}

export function safeStorageFileName(fileName: string, fallbackName: string) {
  const extension = fileName.split(".").pop()?.toLowerCase() || "bin";
  const name = fileName
    .replace(/\.[^/.]+$/, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 42);

  return `${name || fallbackName}.${extension}`;
}

export function createStorageObjectName(fileName: string, fallbackName: string) {
  const id =
    typeof crypto !== "undefined" && "randomUUID" in crypto
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.round(Math.random() * 100000)}`;

  return `${id}-${safeStorageFileName(fileName, fallbackName)}`;
}

export function storagePathFromPublicUrl(url: string, bucketName: string) {
  const marker = `/storage/v1/object/public/${bucketName}/`;
  const markerIndex = url.indexOf(marker);

  if (markerIndex === -1) {
    return null;
  }

  return decodeURIComponent(url.slice(markerIndex + marker.length));
}
