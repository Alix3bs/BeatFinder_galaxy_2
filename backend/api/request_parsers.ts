import type { IncomingMessage } from "node:http";

const HEADER_SEPARATOR = Buffer.from("\r\n\r\n", "utf8");

type MultipartPart = {
  headers: Record<string, string>;
  data: Buffer;
};

export class PayloadTooLargeError extends Error {
  limitBytes: number;

  constructor(limitBytes: number) {
    super(`Request body exceeds the ${limitBytes} byte limit.`);
    this.limitBytes = limitBytes;
  }
}

export type ReadPayloadOptions = {
  maxBytes?: number;
};

export async function readRequestPayload(
  req: IncomingMessage,
  options: ReadPayloadOptions = {},
): Promise<Record<string, unknown>> {
  const contentType = String(req.headers["content-type"] || "");
  const rawBody = await readRawBody(req, options);
  if (!rawBody.length) {
    return {};
  }
  if (contentType.includes("multipart/form-data")) {
    return parseMultipartPayload(rawBody, contentType);
  }
  const text = rawBody.toString("utf8").trim();
  return text ? (JSON.parse(text) as Record<string, unknown>) : {};
}

export async function readRawBody(
  req: IncomingMessage,
  options: ReadPayloadOptions = {},
): Promise<Buffer> {
  const maxBytes = options.maxBytes ?? Number.POSITIVE_INFINITY;
  // Drain moderately-oversized bodies so the client can read the 413
  // response instead of hitting a broken pipe; hard-abort beyond the cap.
  const drainCapBytes = Number.isFinite(maxBytes) ? maxBytes * 4 : Number.POSITIVE_INFINITY;

  const declaredLength = Number.parseInt(String(req.headers?.["content-length"] || ""), 10);
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    if (declaredLength > drainCapBytes) {
      req.destroy();
    } else {
      await drainStream(req);
    }
    throw new PayloadTooLargeError(maxBytes);
  }

  const chunks: Buffer[] = [];
  let received = 0;
  let overLimit = false;
  for await (const chunk of req) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    received += buffer.length;
    if (received > maxBytes) {
      overLimit = true;
      chunks.length = 0;
      if (received > drainCapBytes) {
        req.destroy();
        break;
      }
      continue;
    }
    if (!overLimit) {
      chunks.push(buffer);
    }
  }
  if (overLimit) {
    throw new PayloadTooLargeError(maxBytes);
  }
  return Buffer.concat(chunks);
}

async function drainStream(req: IncomingMessage): Promise<void> {
  try {
    for await (const _chunk of req) {
      // discard
    }
  } catch {
    // The connection may already be gone; the caller still reports 413.
  }
}

export function parseMultipartPayload(body: Buffer, contentType: string): Record<string, unknown> {
  const boundary = extractBoundary(contentType);
  const parts = parseMultipartParts(body, boundary);
  const payload: Record<string, unknown> = {};

  for (const part of parts) {
    const disposition = parseContentDisposition(part.headers["content-disposition"] || "");
    const fieldName = disposition.name;
    if (!fieldName) {
      continue;
    }

    if (disposition.filename) {
      payload.audio_base64 = part.data.toString("base64");
      payload.audio_file_name = disposition.filename;
      payload.audio_mime_type = part.headers["content-type"] || "application/octet-stream";
      continue;
    }

    const coerced = coerceFormField(part.data.toString("utf8"));
    appendField(payload, fieldName, coerced);
  }

  return payload;
}

export function extractBoundary(contentType: string): string {
  const match = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType);
  const boundary = (match?.[1] || match?.[2] || "").trim();
  if (!boundary) {
    throw new Error("Multipart request is missing a boundary.");
  }
  return boundary;
}

export function parseMultipartParts(body: Buffer, boundary: string): MultipartPart[] {
  const boundaryMarker = Buffer.from(`--${boundary}`, "utf8");
  const trailingMarker = Buffer.from(`--${boundary}--`, "utf8");
  const parts: MultipartPart[] = [];

  let cursor = body.indexOf(boundaryMarker);
  if (cursor < 0) {
    return parts;
  }

  while (cursor >= 0) {
    cursor += boundaryMarker.length;
    if (matchesAt(body, trailingMarker, cursor - boundaryMarker.length)) {
      break;
    }
    if (matchesLiteral(body, cursor, "\r\n")) {
      cursor += 2;
    }

    const nextBoundary = body.indexOf(boundaryMarker, cursor);
    if (nextBoundary < 0) {
      break;
    }

    let partBuffer = body.subarray(cursor, nextBoundary);
    if (partBuffer.length >= 2 && partBuffer.subarray(partBuffer.length - 2).equals(Buffer.from("\r\n"))) {
      partBuffer = partBuffer.subarray(0, partBuffer.length - 2);
    }

    const headerIndex = partBuffer.indexOf(HEADER_SEPARATOR);
    if (headerIndex < 0) {
      cursor = nextBoundary;
      continue;
    }

    const headerText = partBuffer.subarray(0, headerIndex).toString("utf8");
    const data = partBuffer.subarray(headerIndex + HEADER_SEPARATOR.length);
    parts.push({
      headers: parseHeaders(headerText),
      data,
    });

    cursor = nextBoundary;
  }

  return parts;
}

export function parseHeaders(headerText: string): Record<string, string> {
  const headers: Record<string, string> = {};
  for (const line of headerText.split("\r\n")) {
    const separator = line.indexOf(":");
    if (separator <= 0) {
      continue;
    }
    const key = line.slice(0, separator).trim().toLowerCase();
    const value = line.slice(separator + 1).trim();
    headers[key] = value;
  }
  return headers;
}

export function parseContentDisposition(header: string): { name?: string; filename?: string } {
  const result: { name?: string; filename?: string } = {};
  for (const segment of header.split(";")) {
    const [rawKey, rawValue] = segment.split("=");
    const key = rawKey.trim().toLowerCase();
    const value = rawValue?.trim().replace(/^"|"$/g, "");
    if (key === "name" && value) {
      result.name = value;
    }
    if (key === "filename" && value) {
      result.filename = value;
    }
  }
  return result;
}

export function coerceFormField(value: string): unknown {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }
  if ((trimmed.startsWith("[") && trimmed.endsWith("]")) || (trimmed.startsWith("{") && trimmed.endsWith("}"))) {
    try {
      return JSON.parse(trimmed);
    } catch {
      return trimmed;
    }
  }
  if (/^-?\d+$/.test(trimmed)) {
    return Number.parseInt(trimmed, 10);
  }
  if (/^-?\d+\.\d+$/.test(trimmed)) {
    return Number.parseFloat(trimmed);
  }
  if (/^(true|false)$/i.test(trimmed)) {
    return trimmed.toLowerCase() === "true";
  }
  return trimmed;
}

function appendField(payload: Record<string, unknown>, fieldName: string, value: unknown): void {
  const existing = payload[fieldName];
  if (existing === undefined) {
    payload[fieldName] = value;
    return;
  }
  if (Array.isArray(existing)) {
    existing.push(value);
    return;
  }
  payload[fieldName] = [existing, value];
}

function matchesLiteral(body: Buffer, index: number, literal: string): boolean {
  return body.subarray(index, index + literal.length).equals(Buffer.from(literal, "utf8"));
}

function matchesAt(body: Buffer, candidate: Buffer, index: number): boolean {
  return body.subarray(index, index + candidate.length).equals(candidate);
}
