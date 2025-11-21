import express, { Request, Response } from 'express';
import { pool } from '../db/queries';

const router = express.Router();

/**
 * POST /api/waitlist
 * Add email to waitlist
 */
router.post('/', async (req: Request, res: Response) => {
    try {
        const { email } = req.body;

        // Validate email
        if (!email || typeof email !== 'string') {
            return res.status(400).json({
                success: false,
                message: 'Email is required'
            });
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid email format'
            });
        }

        const normalizedEmail = email.toLowerCase().trim();

        // Check if already on waitlist
        const checkQuery = 'SELECT * FROM waitlist WHERE email = $1';
        const existingUser = await pool.query(checkQuery, [normalizedEmail]);

        if (existingUser.rows.length > 0) {
            return res.status(200).json({
                success: true,
                message: 'You\'re already on the waitlist!',
                alreadyExists: true
            });
        }

        // Add to waitlist
        const insertQuery = `
            INSERT INTO waitlist (email, signed_up_at, source)
            VALUES ($1, NOW(), $2)
            RETURNING id, email, signed_up_at
        `;

        const source = req.headers.referer || 'landing-page';
        const result = await pool.query(insertQuery, [normalizedEmail, source]);

        // Log waitlist signup
        console.log(`✉️ New waitlist signup: ${normalizedEmail} from ${source}`);

        // TODO: Send welcome email (integrate with SendGrid/Mailgun)
        // await sendWelcomeEmail(normalizedEmail);

        res.status(201).json({
            success: true,
            message: 'Successfully joined the waitlist!',
            data: {
                email: result.rows[0].email,
                position: await getWaitlistPosition(result.rows[0].id)
            }
        });

    } catch (error) {
        console.error('Waitlist signup error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error. Please try again later.'
        });
    }
});

/**
 * GET /api/waitlist/stats
 * Get waitlist statistics (for admin)
 */
router.get('/stats', async (req: Request, res: Response) => {
    try {
        const statsQuery = `
            SELECT
                COUNT(*) as total_signups,
                COUNT(*) FILTER (WHERE signed_up_at > NOW() - INTERVAL '24 hours') as signups_today,
                COUNT(*) FILTER (WHERE signed_up_at > NOW() - INTERVAL '7 days') as signups_week,
                MIN(signed_up_at) as first_signup,
                MAX(signed_up_at) as latest_signup
            FROM waitlist
        `;

        const result = await pool.query(statsQuery);

        res.json({
            success: true,
            data: result.rows[0]
        });

    } catch (error) {
        console.error('Waitlist stats error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch stats'
        });
    }
});

/**
 * Helper: Get user's position in waitlist
 */
async function getWaitlistPosition(userId: number): Promise<number> {
    const query = `
        SELECT COUNT(*) as position
        FROM waitlist
        WHERE id <= $1
    `;
    const result = await pool.query(query, [userId]);
    return parseInt(result.rows[0].position);
}

export default router;
