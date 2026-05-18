import { AdminCoupon, adminGet } from '../../lib/admin-api';
import { createCoupon, toggleCoupon } from './actions';

export default async function CouponsPage() {
  const coupons = await adminGet<AdminCoupon[]>('/admin/coupons', []);

  return (
    <>
      <h1>Coupons</h1>
      <section className="card">
        <h2>Create Coupon</h2>
        <form className="form-row" action={createCoupon}>
          <input name="code" placeholder="WELCOME10" />
          <input name="description" placeholder="Description" />
          <input name="percent" type="number" min="1" max="100" placeholder="%" />
          <button type="submit">Create</button>
        </form>
      </section>
      <section className="card" style={{ marginTop: 20 }}>
        <table className="table">
          <thead>
            <tr>
              <th>Code</th>
              <th>Description</th>
              <th>Discount</th>
              <th>Status</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {coupons.map((coupon) => (
              <tr key={coupon.id}>
                <td>{coupon.code}</td>
                <td>{coupon.description ?? '-'}</td>
                <td>{JSON.stringify(coupon.discount)}</td>
                <td>{coupon.active ? 'ACTIVE' : 'PAUSED'}</td>
                <td>
                  <form action={toggleCoupon}>
                    <input type="hidden" name="couponId" value={coupon.id} />
                    <input type="hidden" name="active" value={String(coupon.active)} />
                    <button type="submit">{coupon.active ? 'Pause' : 'Activate'}</button>
                  </form>
                </td>
              </tr>
            ))}
            {coupons.length === 0 && (
              <tr>
                <td colSpan={5}>No coupons loaded.</td>
              </tr>
            )}
          </tbody>
        </table>
      </section>
    </>
  );
}
