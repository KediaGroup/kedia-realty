"use client";

import Image from "next/image";
import { useRef, useState } from "react";

import {
  createSupabaseBrowserClient,
  hasSupabaseEnv,
} from "@/lib/supabase/client";
import {
  createStorageObjectName,
  projectImageAccept,
  projectImageMimeTypes,
  projectImagesBucket,
  storagePathFromPublicUrl,
  unsupportedProjectImageMessage,
} from "@/lib/storage";
import { LoadingSpinner } from "@/components/ui/LoadingSpinner";
import { adminButton } from "@/lib/admin-ui";

type LayoutImageUploaderProps = {
  value: string;
  onChange: (value: string) => void;
  projectSlug: string;
  layoutIndex: number;
};

export function LayoutImageUploader({
  value,
  onChange,
  projectSlug,
  layoutIndex,
}: LayoutImageUploaderProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const canUpload = hasSupabaseEnv();

  const uploadFile = async (file: File | undefined) => {
    if (!file) {
      return;
    }

    if (!projectImageMimeTypes.includes(file.type)) {
      setMessage(unsupportedProjectImageMessage);
      return;
    }

    if (!canUpload) {
      setMessage("Supabase environment variables are required for uploads.");
      return;
    }

    setIsUploading(true);
    setMessage(null);

    try {
      const supabase = createSupabaseBrowserClient();
      const projectFolder = projectSlug || "draft-project";
      const path = `layouts/${projectFolder}/layout-${
        layoutIndex + 1
      }/${createStorageObjectName(file.name, "layout-plan")}`;
      const { error } = await supabase.storage
        .from(projectImagesBucket)
        .upload(path, file, {
          cacheControl: "31536000",
          upsert: false,
        });

      if (error) {
        throw error;
      }

      const { data } = supabase.storage.from(projectImagesBucket).getPublicUrl(path);
      onChange(data.publicUrl);
      setMessage("Layout image uploaded.");
    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : "Unable to upload layout image.",
      );
    } finally {
      setIsUploading(false);
      if (inputRef.current) {
        inputRef.current.value = "";
      }
    }
  };

  const removeImage = async () => {
    const previousValue = value;
    onChange("");

    if (!canUpload) {
      return;
    }

    const path = storagePathFromPublicUrl(previousValue, projectImagesBucket);

    if (!path) {
      return;
    }

    try {
      const supabase = createSupabaseBrowserClient();
      await supabase.storage.from(projectImagesBucket).remove([path]);
    } catch {
      setMessage("The layout image was removed here, but storage deletion failed.");
    }
  };

  return (
    <div className="grid gap-3 md:col-span-2">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.16em] text-primary-navy">
            Layout image
          </p>
          <p className="mt-1 text-xs leading-5 text-slate-gray">
            Upload a plan image. No image URL is needed.
          </p>
        </div>
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          disabled={isUploading || !canUpload}
          aria-busy={isUploading}
          className={adminButton(
            "primary",
            "compact",
            "disabled:cursor-wait disabled:opacity-50",
          )}
        >
          <span className="inline-flex items-center justify-center gap-2">
            {isUploading ? <LoadingSpinner /> : null}
            {isUploading ? "Uploading" : value ? "Replace image" : "Upload image"}
          </span>
        </button>
      </div>
      <input
        ref={inputRef}
        type="file"
        accept={projectImageAccept}
        className="rounded-lg sr-only"
        onChange={(event) => uploadFile(event.target.files?.[0])}
      />

      {value ? (
        <div className="rounded-lg border border-border-gray bg-white p-3">
          <div className="relative aspect-[16/10] overflow-hidden rounded-md bg-cool-mist">
            <Image
              src={value}
              alt={`Layout ${layoutIndex + 1} image preview`}
              fill
              sizes="(min-width: 768px) 40vw, 100vw"
              className="object-contain"
            />
          </div>
          <button
            type="button"
            onClick={removeImage}
            className="mt-3 min-h-9 rounded-lg border border-border-gray px-3 text-[0.65rem] font-semibold uppercase tracking-[0.14em] text-slate-gray transition hover:border-red-300 hover:text-red-700"
          >
            Delete image
          </button>
        </div>
      ) : (
        <div className="rounded-lg border border-dashed border-border-gray bg-white p-5 text-sm leading-7 text-slate-gray">
          No layout image uploaded yet.
        </div>
      )}

      {!canUpload ? (
        <p className="text-xs leading-6 text-red-700">
          Configure Supabase environment variables before uploading layout images.
        </p>
      ) : null}
      {message ? (
        <p className="text-xs leading-6 text-slate-gray">{message}</p>
      ) : null}
    </div>
  );
}
