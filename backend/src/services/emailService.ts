import nodemailer from 'nodemailer';

const SMTP_TIMEOUT_MS = 10_000; // 10 seconds max for SMTP operations

const getTransporter = () => {
    const host = process.env.SMTP_HOST;
    const port = process.env.SMTP_PORT ? Number(process.env.SMTP_PORT) : undefined;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (!host || !port || !user || !pass) {
        return null;
    }

    return nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
        connectionTimeout: SMTP_TIMEOUT_MS,
        greetingTimeout: SMTP_TIMEOUT_MS,
        socketTimeout: SMTP_TIMEOUT_MS,
    });
};

export const sendEmailOtp = async (to: string, code: string) => {
    const transporter = getTransporter();
    const from = process.env.SMTP_FROM || 'no-reply@familysphere.app';
    const subject = 'FamilySphere verification code';
    const text = `Your FamilySphere verification code is: ${code}. It expires in 10 minutes.`;

    if (!transporter) {
        // Fallback for dev when SMTP isn't configured.
        // eslint-disable-next-line no-console
        console.log(`[Email OTP] ${to} -> ${code}`);
        return;
    }

    // Race against a timeout so we never hang the endpoint
    const sendPromise = transporter.sendMail({ from, to, subject, text });
    const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('SMTP send timed out')), SMTP_TIMEOUT_MS),
    );

    await Promise.race([sendPromise, timeoutPromise]);
};
