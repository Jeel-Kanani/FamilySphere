import { Resend } from 'resend';

/**
 * Email service using Resend (HTTPS-based, works on Render free tier).
 *
 * Required env vars:
 *   RESEND_API_KEY  – API key from resend.com
 *   RESEND_FROM     – Sender address (e.g., "FamilySphere <onboarding@resend.dev>")
 */

const getResend = (): Resend | null => {
    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) return null;
    return new Resend(apiKey);
};

export const sendEmailOtp = async (to: string, code: string) => {
    const resend = getResend();
    const from = process.env.RESEND_FROM || 'FamilySphere <onboarding@resend.dev>';

    if (!resend) {
        // Fallback for dev when Resend isn't configured
        console.log(`[Email OTP - DEV FALLBACK] ${to} -> ${code}`);
        return;
    }

    const { error } = await resend.emails.send({
        from,
        to,
        subject: 'FamilySphere — Your Verification Code',
        html: `
            <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
                <h2 style="color: #2563EB; margin-bottom: 24px;">FamilySphere</h2>
                <p style="font-size: 16px; color: #333;">Your verification code is:</p>
                <div style="background: #EFF6FF; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
                    <span style="font-size: 36px; font-weight: bold; letter-spacing: 10px; color: #2563EB;">${code}</span>
                </div>
                <p style="font-size: 14px; color: #666;">This code expires in <strong>10 minutes</strong>. If you didn't request this, please ignore this email.</p>
            </div>
        `,
        text: `Your FamilySphere verification code is: ${code}. It expires in 10 minutes.`,
    });

    if (error) {
        console.error('[OTP] Resend error:', error);
        throw new Error(`Email send failed: ${error.message}`);
    }

    console.log(`[OTP] Email sent via Resend to ${to}`);
};

export const sendFamilyInviteEmail = async (
    to: string,
    inviterName: string,
    familyName: string,
    inviteUrl: string,
) => {
    const resend = getResend();
    const from = process.env.RESEND_FROM || 'FamilySphere <onboarding@resend.dev>';

    if (!resend) {
        console.log(`[Email Invite - DEV FALLBACK] ${to} -> ${inviteUrl}`);
        return;
    }

    const { error } = await resend.emails.send({
        from,
        to,
        subject: `You're invited to join ${familyName} on FamilySphere`,
        html: `
            <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
                <h2 style="color: #2563EB; margin-bottom: 24px;">FamilySphere</h2>
                <p style="font-size: 16px; color: #333;"><strong>${inviterName}</strong> has invited you to join the family:</p>
                <h3 style="color: #333; margin: 16px 0;">${familyName}</h3>
                <div style="margin: 32px 0;">
                    <a href="${inviteUrl}" target="_blank"
                       style="background: #2563EB; color: white; padding: 14px 28px; border-radius: 8px; text-decoration: none; font-weight: bold; display: inline-block;">
                        Accept Invitation
                    </a>
                </div>
                <p style="font-size: 14px; color: #666;">This invitation expires in 48 hours.<br>If the button doesn't work, copy and paste this link:<br>${inviteUrl}</p>
            </div>
        `,
        text: `${inviterName} has invited you to join "${familyName}" on FamilySphere. Join here: ${inviteUrl}`,
    });

    if (error) {
        console.error('[Invite] Resend error:', error);
        throw new Error(`Invitation email failed: ${error.message}`);
    }

    console.log(`[Invite] Email sent via Resend to ${to}`);
};

export const sendPasswordResetEmail = async (to: string, resetUrl: string) => {
    const resend = getResend();
    const from = process.env.RESEND_FROM || 'FamilySphere <onboarding@resend.dev>';

    if (!resend) {
        console.log(`[Password Reset - DEV FALLBACK] ${to} -> ${resetUrl}`);
        return;
    }

    const { error } = await resend.emails.send({
        from,
        to,
        subject: 'FamilySphere — Reset Your Password',
        html: `
            <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
                <h2 style="color: #2563EB; margin-bottom: 24px;">FamilySphere</h2>
                <p style="font-size: 16px; color: #333;">We received a request to reset your password.</p>
                <div style="margin: 32px 0;">
                    <a href="${resetUrl}" target="_blank"
                       style="background: #2563EB; color: white; padding: 14px 28px; border-radius: 8px; text-decoration: none; font-weight: bold; display: inline-block;">
                        Reset Password
                    </a>
                </div>
                <p style="font-size: 14px; color: #666;">This link expires in <strong>15 minutes</strong>. If you didn't request a reset, you can safely ignore this email.</p>
                <p style="font-size: 12px; color: #999;">Or copy this link: ${resetUrl}</p>
            </div>
        `,
        text: `Reset your FamilySphere password here: ${resetUrl} (expires in 15 minutes)`,
    });

    if (error) {
        console.error('[PasswordReset] Resend error:', error);
        throw new Error(`Password reset email failed: ${error.message}`);
    }

    console.log(`[PasswordReset] Email sent via Resend to ${to}`);
};
