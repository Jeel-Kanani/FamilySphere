import { Resend } from 'resend';

/**
 * Email service using Resend HTTP API.
 * Works on Render free tier (uses HTTPS port 443, not SMTP ports).
 *
 * Required env vars:
 *   RESEND_API_KEY  – API key from https://resend.com/api-keys
 *   RESEND_FROM     – Sender address (e.g. "onboarding@resend.dev" for testing)
 */

const getResendClient = (): Resend | null => {
    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) return null;
    return new Resend(apiKey);
};

export const sendEmailOtp = async (to: string, code: string) => {
    const resend = getResendClient();
    const from = process.env.RESEND_FROM || 'FamilySphere <onboarding@resend.dev>';
    const subject = 'FamilySphere verification code';
    const text = `Your FamilySphere verification code is: ${code}. It expires in 10 minutes.`;
    const html = `
        <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
            <h2 style="color: #6C63FF; margin-bottom: 24px;">FamilySphere</h2>
            <p style="font-size: 16px; color: #333;">Your verification code is:</p>
            <div style="background: #f4f4f8; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
                <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #6C63FF;">${code}</span>
            </div>
            <p style="font-size: 14px; color: #666;">This code expires in 10 minutes. If you didn't request this, please ignore this email.</p>
        </div>
    `;

    if (!resend) {
        // Fallback for dev when Resend isn't configured
        // eslint-disable-next-line no-console
        console.log(`[Email OTP] ${to} -> ${code}`);
        return;
    }

    const { error } = await resend.emails.send({
        from,
        to,
        subject,
        text,
        html,
    });

    if (error) {
        console.error('[OTP] Resend API error:', error.message);
        throw new Error(`Email send failed: ${error.message}`);
    }
};
