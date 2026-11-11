# Moving a Domain from GoDaddy to AWS Route 53

## Simple idea

Think of DNS as a phone book.

- A domain like `cloudbinocular.online` is just a name.
- DNS tells the internet which server that name points to.
- Right now, GoDaddy is acting as the “phone book” for your domain.
- You want AWS Route 53 to act as the phone book instead, because that is where you can create and manage records for your app and later automate them.

The key idea is this:

- You still own the domain at GoDaddy.
- You are only changing who is responsible for the DNS records.
- The domain registration stays with GoDaddy.
- The DNS hosting moves to Route 53.

## What is a nameserver?

A nameserver is just the server that answers: “Who keeps the DNS records for this domain?”

When you move DNS hosting,

1. You create a hosted zone in Route 53.
2. Route 53 gives you 4 nameserver addresses.
3. You tell GoDaddy: “For this domain, use those 4 nameservers instead.”

That is the whole move.

---

# Step 1: Create the hosted zone in Route 53

1. Sign in to AWS.
2. Open Route 53.
3. Make sure you are in your personal AWS account.
4. In the left menu, click `Hosted zones`.
5. Click `Create hosted zone`.
6. Fill in:
   - Domain name: `cloudbinocular.online`
   - Type: `Public hosted zone`
7. Click `Create hosted zone`.

After it is created, open the hosted zone.

You will see a few records already there. Look for the one whose type is `NS`.

That record contains 4 values, like this:

```text
ns-123.awsdns-45.com
ns-678.awsdns-12.net
ns-901.awsdns-34.org
ns-234.awsdns-56.co.uk
```

These are example values only. Your values will be different.

Important:

- Copy the 4 values from your Route 53 NS record.
- Some may end with a dot.
- When you paste them into GoDaddy, remove the trailing dot.

---

# Step 2: Update the nameservers in GoDaddy

The layout of GoDaddy can change over time, but the idea is always the same.

1. Sign in to GoDaddy.
2. Open `My Products` or `Domain Portfolio`.
3. Find `cloudbinocular.online`.
4. Click `DNS` or `Manage DNS`.
5. Find the `Nameservers` section.
6. Click `Change Nameservers`.
7. Select the option that says something like:
   - `I’ll use my own nameservers`
   - or `Enter my own nameservers (advanced)`
8. Paste your 4 Route 53 nameserver values into the boxes.
9. If GoDaddy shows only 2 boxes, click `Add Nameserver` until you have 4 total.
10. Save the change.

You may see a warning like “GoDaddy DNS will stop being used.” That is normal and expected.

---

# Step 3: Verify the change

The DNS change does not happen instantly. It can take a few minutes, sometimes a few hours, and in rare cases up to 48 hours.

To check from your laptop, run:

```bash
nslookup -type=NS cloudbinocular.online
```

Or use a public DNS server:

```bash
nslookup -type=NS cloudbinocular.online 8.8.8.8
```

You can also try:

```bash
nslookup -type=NS cloudbinocular.online 1.1.1.1
```

### What success looks like

If the move worked, you should see nameserver values that look like AWS names, such as:

- `awsdns-*`
- values beginning with `ns-...awsdns...`

If you still see GoDaddy nameservers, the change has not fully propagated yet.

You may need to:

- wait a bit longer
- restart your internet connection or Wi‑Fi
- test again later

If you have `dig`, this also works:

```bash
dig NS cloudbinocular.online +short
```

---

# Important things to watch for

## 1. Do not create DNS records in GoDaddy anymore

Once the nameservers are moved, GoDaddy is no longer the authority for your DNS records.

All future records should be created in Route 53, not in GoDaddy.

## 2. Turn off DNSSEC if it is enabled

If GoDaddy has DNSSEC enabled for the domain, turn it off before changing nameservers.

Why?

- DNSSEC can sometimes prevent the domain from resolving properly during a nameserver change.
- It is often off by default, but it is worth checking.

---

# Final note

This part of the setup is only the DNS foundation.

Nothing else is needed here until the cluster exists. After the first deployment or apply, you will create the CNAME records inside the Route 53 hosted zone.

In short:

- GoDaddy keeps the domain ownership.
- Route 53 becomes the DNS manager.
- The nameserver change tells the internet where to look for your DNS records.
