# Lab 9 cost comparison

Estimate in USD per 730-hour month, before credits and taxes. AWS is us-east-1 and GCP is us-central1. AWS Pricing Calculator returned $38.24 for Fargate, ALB with busy traffic and three public IPv4 addresses. Google Cloud Pricing Calculator returned $9.37 for Cloud SQL and zero-request Cloud Run. The remaining scenarios use published rates and the traffic assumptions below. The Google calculator offers preset request counts, so the busy GCP value is calculated from its underlying rates at exactly 13,140,000 requests.

The comparison covers the core application. On AWS the verified service uses one Linux/x86 Fargate task with 0.25 vCPU and 1 GiB, with one public task IP and two public ALB addresses observed at the time of checking. Supabase is modeled within its Free plan. The lab's reference Lambda and Aurora stack differs from this deployed architecture. On Google Cloud the estimate uses Cloud Run with 1 vCPU, 512 MiB and zero minimum instances, plus one Cloud SQL Enterprise db-f1-micro instance with 10 GiB SSD. The fixed baseline keeps the two databases available through the month.

| Core component | AWS monthly baseline | GCP monthly baseline |
| --- | ---: | ---: |
| Frontend, CDN and HTTPS | $0 within CloudFront/S3 allowances | $0 within Firebase Hosting allowances |
| API compute | $10.63 Fargate | $0 at low traffic within Cloud Run free quota |
| Public routing | $16.43 ALB, plus $10.95 for three public IPv4 addresses | Included HTTPS on Cloud Run and Firebase Hosting |
| PostgreSQL compute | $0 assumed on Supabase Free | $7.67 for 730 hours |
| PostgreSQL storage | $0 within Supabase Free | $1.70 for 10 GiB SSD |
| Registry, logs and secrets | Small charges excluded from baseline | Within free quotas under the assumptions below |
| **Core subtotal before traffic charges** | **$38.01** | **$9.37** |

## Four profiles

| Profile | Monthly API requests assumed | AWS | GCP | Lower cost and deciding line |
| --- | ---: | ---: | ---: | --- |
| Nobody | 0 | $38.01 | $9.37 | GCP. AWS ALB hours alone exceed the GCP core total. |
| Class demos, 10 × 2 h | 2,400 | ≈ $38.01 | ≈ $9.37 | GCP. AWS ALB hours still accrue between demos. |
| Office hours, 8 h × 22 days | 21,120 | ≈ $38.01 | ≈ $9.37 | GCP. The ALB baseline remains larger than the GCP core total. |
| Busy around the clock | 13,140,000 | ≈ $38.24 | ≈ $76.34 | AWS in this model. The $58.75 Cloud Run active CPU line decides it. |

For demos and office hours assume 120 requests per active hour, 0.2 seconds billed per request and about 1 KiB outbound per response. For the busy profile assume 5 requests per second with one fully occupied Cloud Run instance equivalent, 0.04 ALB LCU on average and the same response size. The busy GCP subtotal includes about $58.75 for CPU, $2.39 for memory, $4.46 for requests and $1.38 for North American API egress. Actual concurrency, response size and egress destination can change this result. The busy comparison is a price model, with no claim that the current small databases sustain that load.

Assume available Cloud Run monthly quotas of 2M requests, 180,000 vCPU-seconds and 360,000 GiB-seconds, plus 1 GiB of North American internet egress. Static frontend traffic is assumed under 360 MB/day on Firebase, and retained GCP images under 0.5 GB. One active database secret, low log volume and one migration run have negligible cost in this model. Assume AWS/Supabase storage and outbound traffic are within the selected free allowances, including the Supabase limits of 500 MB database size and 5 GB uncached egress. A paused Supabase project needs to resume before serving requests. These are assumptions, not billed amounts.

The GCP idle-cost trap is Cloud SQL. Cloud Run can scale to zero, but Cloud SQL compute keeps billing while it runs without requests. A stopped instance still has storage charges and can incur $0.01 per hour for a retained idle IPv4 address. With both, stopping it for a whole month would still cost about $9 in this configuration. Delete the lab instance after grading to end those charges.

[AWS Fargate](https://aws.amazon.com/fargate/pricing/), [AWS ALB](https://aws.amazon.com/elasticloadbalancing/pricing/), [AWS IPv4](https://aws.amazon.com/vpc/pricing/), [Supabase](https://supabase.com/pricing), [Cloud Run](https://cloud.google.com/run/pricing), [Cloud SQL](https://cloud.google.com/sql/pricing), [Google Cloud networking](https://cloud.google.com/vpc/network-pricing), [Firebase Hosting](https://firebase.google.com/pricing/).
