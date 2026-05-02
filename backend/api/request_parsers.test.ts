import test from "node:test";
import assert from "node:assert/strict";

import { parseMultipartPayload } from "./request_parsers.ts";

test("parseMultipartPayload extracts file bytes and coerces JSON-ish fields", () => {
  const boundary = "beatfinder-boundary";
  const body = Buffer.concat([
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="title"\r\n\r\n`),
    Buffer.from("SZA x Summer Walker Type Beat - Late Nights\r\n"),
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="hashtags"\r\n\r\n`),
    Buffer.from('["#phillytypebeat"]\r\n'),
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="top_n"\r\n\r\n`),
    Buffer.from("5\r\n"),
    Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="audio"; filename="late_nights.wav"\r\nContent-Type: audio/wav\r\n\r\n`,
    ),
    Buffer.from([0x52, 0x49, 0x46, 0x46, 0x01, 0x02, 0x03, 0x04]),
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ]);

  const payload = parseMultipartPayload(body, `multipart/form-data; boundary=${boundary}`);
  assert.equal(payload.title, "SZA x Summer Walker Type Beat - Late Nights");
  assert.deepEqual(payload.hashtags, ["#phillytypebeat"]);
  assert.equal(payload.top_n, 5);
  assert.equal(payload.audio_file_name, "late_nights.wav");
  assert.equal(payload.audio_mime_type, "audio/wav");
  assert.equal(payload.audio_base64, Buffer.from([0x52, 0x49, 0x46, 0x46, 0x01, 0x02, 0x03, 0x04]).toString("base64"));
});
