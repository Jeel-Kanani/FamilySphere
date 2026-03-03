# Tesseract.js OCR Implementation (Legacy Backup)

This document contains the complete technical details and code for the local Tesseract.js OCR pipeline used in FamilySphere. This can be used as a reference if you ever wish to revert to local OCR or implement a hybrid (offline-first) processing model.

## Core Dependencies
```bash
npm install tesseract.js sharp
```

## Implementation Details

### 1. Image Pre-processing (Highly Critical)
Local OCR accuracy depends heavily on image quality. We use `sharp` to normalize and sharpen images before sending them to Tesseract.

```typescript
import sharp from 'sharp';

async function preprocessImage(rawBuffer: Buffer): Promise<Buffer> {
    return await sharp(rawBuffer)
        .grayscale()
        .normalise()
        .linear(1.2, -20)   // Contrast boost: gain=1.2, offset=-20
        .sharpen({ sigma: 1.5 })
        .toBuffer();
}
```

### 2. Tesseract Configuration
We use `eng+hin` (English + Hindi) with Page Segmentation Mode (PSM) 6, which is optimized for structured documents/forms.

```typescript
import Tesseract from 'tesseract.js';

const result = await Tesseract.recognize(imageBuffer, 'eng+hin', {
    // PSM 6: Assume a single uniform block of text.
    tessedit_pageseg_mode: '6', 
});
const { text, confidence } = result.data;
```

### 3. Full Extraction Logic (Original ocrService.ts snippet)
This snippet handles downloading, preprocessing, and the multi-lingual fallback logic.

```typescript
async function extractTextFromUrl(fileUrl: string, page: number): Promise<{ text: string; ocrConfidence: number; rawBuffer?: Buffer }> {
    const ocrUrl = transformUrlForOcr(fileUrl, page);
    const rawBuffer = await downloadToBuffer(ocrUrl);
    
    let imageBuffer: Buffer;
    try {
        imageBuffer = await sharp(rawBuffer)
            .grayscale()
            .normalise()
            .linear(1.2, -20)
            .sharpen({ sigma: 1.5 })
            .toBuffer();
    } catch (err) {
        imageBuffer = rawBuffer;
    }

    let text = '';
    let ocrConfidence = 0;
    try {
        // Primary Attempt: English + Hindi
        const result = await Tesseract.recognize(imageBuffer, 'eng+hin', {
            tessedit_pageseg_mode: '6',
        });
        text = result.data.text;
        ocrConfidence = result.data.confidence;
    } catch (tessErr) {
        // Fallback: English Only
        const fallbackResult = await Tesseract.recognize(imageBuffer, 'eng', {
            tessedit_pageseg_mode: '6',
        });
        text = fallbackResult.data.text;
        ocrConfidence = fallbackResult.data.confidence;
    }

    return { text, ocrConfidence, rawBuffer };
}
```

## Hybrid Logic Ideas
If you want to use both in the future:
1.  **Fast Local Preview**: Run Tesseract locally for immediate results.
2.  **Delayed Cloud Verification**: Background job sends to Gemini Vision for high-accuracy confirmation.
3.  **Cost Savings**: Run Tesseract first; if `confidence < 80%`, then escalate to Gemini Vision.
