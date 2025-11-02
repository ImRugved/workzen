# Leave Calculation Rules Based on Calendar Year (1 Jan - 31 Dec)

## Leave Types and Annual Allocation

- **PL (Privilege Leave)**: 12 per year (1 per month)
- **SL (Sick Leave)**: 6 per year
- **CL (Casual Leave)**: 5 per year (optional)

## Calculation Logic Based on Joining Date (createdAt)

### Date Range Considerations

- Calendar year runs from **1 January to 31 December**
- Leaves are calculated from joining date until 31 December of the same year
- If employee joins between **1 Jan to 10 Jan**: Full year allocation (12 PL, 6 SL, 5 CL)
- If employee joins **after 10 Jan**: Pro-rata calculation applies

### PL (Privilege Leave) Calculation Rules

- **Rate**: 1 PL per month
- **Formula**: Number of months from joining date to 31 Dec (inclusive)
- **Mid-month joining**:
  - If joined between 1st-15th of month: Count full month (1 PL)
  - If joined between 16th-end of month: Count as 0.5 PL
- **Examples**:
  - Joined 15 Jan → 0.5 + 11 months = 11.5 PL (round as per policy)
  - Joined 1 June → 7 months = 7 PL
  - Joined 20 June → 0.5 + 6 months = 6.5 PL

### SL (Sick Leave) Calculation Rules

- **12 months**: 6 SL
- **6-11 months**: 3 SL
- **4-5 months**: 2 SL
- **3 months or less**: 1 SL
- **Examples**:
  - Joined 1 June → 7 months = 3 SL
  - Joined 1 Oct → 3 months = 1 SL
  - Joined 1 Nov → 2 months = 1 SL

### CL (Casual Leave) Calculation Rules

- **12 months**: 5 CL
- **9-11 months**: 4 CL
- **6-8 months**: 2 CL
- **4-5 months**: 1 CL
- **3 months or less**: 0 CL
- **Examples**:
  - Joined 1 June → 7 months = 2 CL
  - Joined 1 Oct → 3 months = 0 CL
  - Joined 1 Sep → 4 months = 1 CL

`

## Edge Cases to Handle

1. **Joining on 1-10 January**: Always full allocation (12 PL, 6 SL, 5 CL)
2. **Mid-month joining (16th-31st)**: Reduce current month PL by 0.5
3. **December joining**: Minimum leaves (1 SL, 0 CL, 1 or 0.5 PL)
4. **Leap year**: February handling for date calculations
5. **Rounding**: Decide policy for 0.5 PL (round up/down/keep decimal)

## Validation Rules

- PL: Range 0.5-12
- SL: Range 1-6
- CL: Range 0-5
- All calculations based on `createdAt` date field
- Reset on 1 January of each new year
