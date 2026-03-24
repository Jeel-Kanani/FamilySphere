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

export const sendFamilyInviteEmail = async (to: string, inviterName: string, familyName: string, inviteUrl: string) => {
    const resend = getResendClient();
    const from = process.env.RESEND_FROM || 'FamilySphere <onboarding@resend.dev>';
    const subject = `Join ${familyName} on FamilySphere`;
    const text = `${inviterName} has invited you to join their family "${familyName}" on FamilySphere. Use this link: ${inviteUrl}`;
    const html = `
        <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
            <h2 style="color: #6C63FF; margin-bottom: 24px;">FamilySphere</h2>
            <p style="font-size: 16px; color: #333;"><strong>${inviterName}</strong> has invited you to join the family:</p>
            <h3 style="color: #333; margin: 16px 0;">${familyName}</h3>
            <div style="margin: 32px 0;">
                <a href="${inviteUrl}" target="_blank" style="background: #6C63FF; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; display: inline-block;">Accept Invitation</a>
            </div>
            <p style="font-size: 14px; color: #666;">This invitation expires in 48 hours. If the button doesn't work, copy and paste this link:<br>${inviteUrl}</p>
        </div>
    `;

    if (!resend) {
        // eslint-disable-next-line no-console
        console.log(`[Email Invite] ${to} -> ${inviteUrl}`);
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
        console.error('[Invite] Resend API error:', error.message);
        throw new Error(`Invitation email failed: ${error.message}`);
    }
};
