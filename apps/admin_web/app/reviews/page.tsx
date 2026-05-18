import { AdminReview, adminGet } from '../../lib/admin-api';
import { moderateReview } from './actions';

export default async function ReviewsPage() {
  const reviews = await adminGet<AdminReview[]>('/admin/reviews', []);

  return (
    <>
      <h1>Reviews And Reports</h1>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Rating</th>
              <th>Provider</th>
              <th>Customer</th>
              <th>Status</th>
              <th>Comment</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {reviews.map((review) => (
              <tr key={review.id}>
                <td>{review.rating}</td>
                <td>{review.providerProfile?.displayName ?? 'Unknown'}</td>
                <td>{review.customerProfile?.user?.fullName ?? review.customerProfile?.user?.phone ?? 'Unknown'}</td>
                <td>{review.status}</td>
                <td>{review.comment ?? '-'}</td>
                <td>
                  <div className="actions">
                    <form action={moderateReview}>
                      <input type="hidden" name="reviewId" value={review.id} />
                      <input type="hidden" name="status" value="PUBLISHED" />
                      <button type="submit">Publish</button>
                    </form>
                    <form action={moderateReview}>
                      <input type="hidden" name="reviewId" value={review.id} />
                      <input type="hidden" name="status" value="HIDDEN" />
                      <input type="hidden" name="reportReason" value="Hidden by admin" />
                      <button type="submit">Hide</button>
                    </form>
                    <form action={moderateReview}>
                      <input type="hidden" name="reviewId" value={review.id} />
                      <input type="hidden" name="status" value="REPORTED" />
                      <input type="hidden" name="reportReason" value="Marked for follow-up" />
                      <button type="submit">Report</button>
                    </form>
                  </div>
                </td>
              </tr>
            ))}
            {reviews.length === 0 && (
              <tr>
                <td colSpan={6}>No reviews loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
