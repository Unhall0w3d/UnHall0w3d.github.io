---
title: "Making a CUCM 15SU5 ISO Bootable for Lab Use on Proxmox"
description: "Rebuild the CUCM 15SU5 ISO for BIOS boot, install a lab publisher on Proxmox VE 9, and verify SSH and AXL access."
pubDate: 2026-11-19T12:00:00-05:00
pillar: "systems-infrastructure"
tags: ["virtualization", "cucm", "axl", "lab"]
legacyCategories: ["Unified Communications", "Cisco"]
---

Back in 2019 I needed a CUCM lab for recertification. This time I needed a publisher I could point a tool at, send it an AXL request, and see what came back. I had a Proxmox host, some room on thin storage, and a familiar problem. The CUCM ISO I had on hand wouldn't boot.

If you're working with CUCM 12.5 on ESXi, the original post walks through the Windows cdrtools command and gets as far as CUCM appearing in the product selection screen. The ISOLINUX part of that process still works on 15SU5. What I wanted to find out this time was which VM settings would get me *past* that screen, through the install, and into a working publisher. [Making ISOs Bootable for Lab Use (2019)](https://nocthoughts.com/2019/08/14/making-isos-bootable-lab-use.html)

**Lab use only.** I tested build `15.0.1.15900-150` on Proxmox VE 9.2.21. For a Cisco-supported deployment, use the media, hypervisor and sizing in Cisco's installation guidance. The same lab-use qualification applies to the rebuilt media in the older post. [Cisco Release 15 installation planning](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/install/15/cucm_b_install-guide-cucm-imp-15/cucm_m_planning-the-installation.html)

## Step 1 — Check the image you have

I started with `UCSInstall_UCOS_15.0.1.15900-150.sha512.iso`. Inside it were `isolinux/isolinux.bin` and even a file called `isolinux/boot.cat`. Why wouldn't it boot? The ISO had no El Torito boot record to tell the BIOS where to look. The other detail worth catching before rebuilding it was in `ks.cfg`. The installer looks for its media at `/dev/disk/by-label/CDROM`, so the volume label matters.

I used Linux for this build. You'll need `isoinfo` and `mkisofs` from cdrtools, `implantisomd5` and `checkisomd5` from isomd5sum, and enough space for an extracted copy and a second ISO. Run the following blocks in the same Bash shell. Start with the path to your original download.

```bash
src=$(realpath UCSInstall_UCOS_15.0.1.15900-150.sha512.iso)
build=$(mktemp -d "$PWD/cucm-build.XXXXXX")
tree="$build/tree"
out="$build/CUCM-15SU5-lab-bios.iso"
mkdir "$tree" "$build/mnt"

sha512sum "$src"
isoinfo -d -i "$src"
```

Compare the SHA-512 to Cisco's download listing if you have it. I recorded the source hash and verified the files against the manifest inside the image. I didn't independently match the download to Cisco's portal digest during this run.

## Step 2 — Rebuild the ISO and run the media check

Mount the download read-only and copy the whole tree, including the hidden files. The `/.` on the source below picks those up. Work on the extracted copy because `-boot-info-table` updates the boot image while `mkisofs` builds the ISO.

```bash
sudo mount -o loop,ro "$src" "$build/mnt"
cp -R "$build/mnt/." "$tree/"
sudo umount "$build/mnt"
chmod u+w "$tree/isolinux/isolinux.bin"
(cd "$tree" && sha512sum --quiet -c checksum_file_sha512)
```

Resolve any checksum failure before continuing. The checker stays quiet when every entry passes. All 1,766 entries passed here. Next, point `mkisofs` at the ISOLINUX boot image and give the disc the label the installer expects. Keep the output outside the extracted tree.

```bash
mkisofs -quiet -R -J -joliet-long -V CDROM \
  -b isolinux/isolinux.bin -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -o "$out" "$tree"

implantisomd5 --force "$out"
checkisomd5 "$out"
isoinfo -d -i "$out"
sha512sum "$out"
```

Here's what to look for. The rebuilt image reported volume ID `CDROM`, an El Torito x86 entry marked `bootable`, no emulation, and a load size of four sectors. The embedded media check passed. I also checked the rebuilt payload against the same SHA-512 manifest and got all 1,766 entries back clean. The final `sha512sum` gives you a digest for checking your own ISO after copying it to Proxmox. This recipe creates BIOS boot media, so choose SeaBIOS in the next step.

## Step 3 — Give CUCM a VM it recognizes

Upload the rebuilt ISO to storage that accepts ISO images and create a VM. These are the settings that took this publisher all the way through installation.

| Proxmox setting | Value used |
| --- | --- |
| BIOS / machine / display | SeaBIOS / `pc` (i440fx) / Standard VGA |
| CPU | Type `host`, 1 socket, 2 cores |
| Memory | 10,240 MiB, ballooning disabled |
| SCSI controller | VirtIO SCSI (`virtio-scsi-pci`) |
| Disk | One 110 GiB SCSI disk on LVM-thin |
| Network | One VMXNET3 adapter on the lab bridge |
| SMBIOS system manufacturer | `Red Hat` |
| Boot order | SCSI disk first, CD/DVD second, rebuilt ISO attached |
| Start at boot | Disabled for this temporary lab |

The easy setting to miss is **SMBIOS system manufacturer**. On this build, the installer checks that field during hardware detection. With the VM powered off, open **Options → SMBIOS settings** and enter `Red Hat` as the manufacturer. Keep the space. With that value and the SCSI hardware above, the installer reported that NFVIS passed detection validation and completed hardware setup. I left Cisco's hardware checks intact.

I gave the guest 110 GiB because I've had to grow 80 GB disks to around 110–120 GB on later 14.x upgrade paths. Thin provisioning takes some of the sting out of that choice. After this fresh install the thin volume had allocated about 31.4 GiB on the host. I'd still leave room for it to grow, especially if the next thing you want to test is an upgrade.

## Step 4 — Install the publisher

Start the VM and open its console. With a blank disk first in the boot order, it should fall through to the DVD. Run the installer's DVD media test. Mine returned **Success**. After hardware detection, select **Cisco Unified Communications Manager** and continue with a **Basic Install**. I chose a fresh installation, skipped the upgrade patch and configured this as the first node.

Have your static address, gateway, forward and reverse DNS records, and a reachable NTP server ready. The wizard also asks for the platform administrator, application administrator and cluster security password. Keep track of which account is which. You'll use the platform account for SSH and an application account with AXL access for the API check.

One progress bar worth mentioning was item 61 of 84. All 803 MB were already accounted for, but the installer had just started a script with a one-hour estimate. If you reach that screen, give it time. I left the console alone and let the VM come back up from disk.

## Step 5 — See if it answers

First I connected with `ssh PLATFORM_USER@publisher.example.test`, substituting my platform username and publisher name, and ran these from the CUCM CLI.

```text
show version active
utils ntp status
utils service list
```

`show version active` returned `Active Master Version: 15.0.1.15900-150`. NTP showed synchronized, and the service list showed **Cisco AXL Web Service** started. There was a short window during startup when SSH accepted a login but the CLI was slow and the AXL URL still returned HTTP 404. Give the application time to start before troubleshooting the credentials.

For AXL I wanted an actual answer from the database API. I used the read-only `getCCMVersion` operation. Here's the equivalent request with curl. Set `publisher` to the name on your publisher's Tomcat certificate, point `trust` to the trusted Tomcat certificate or its issuing CA in PEM format, and use an application account with AXL access. Curl prompts for the password.

```bash
publisher=publisher.example.test
trust=./publisher-trust.pem
read -rp 'AXL username: ' axl_user

curl --cacert "$trust" --user "$axl_user" \
  --header 'Content-Type: text/xml; charset=utf-8' \
  --header 'SOAPAction: "CUCM:DB ver=15.0 getCCMVersion"' \
  --write-out '\nHTTP %{http_code}\n' \
  --data-binary @- "https://$publisher:8443/axl/" <<'XML'
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:axl="http://www.cisco.com/AXL/API/15.0">
  <soap:Body>
    <axl:getCCMVersion/>
  </soap:Body>
</soap:Envelope>
XML
```

The publisher returned **HTTP 200** and **`15.0.1.15900(150)`** in the SOAP response. That's the same build the CLI reported, and enough to start pointing AXL tools at the lab.

### What about phones?

AXL was already running after the install. **Cisco CallManager** and **Cisco Tftp** both showed **Service Not Activated**. For a lab where I may register a softphone or two, I activated those two services on the publisher. You can do that under **Cisco Unified Serviceability → Tools → Service Activation**. A fresh `utils service list` showed both started. Bulk Provisioning, CTIManager, DirSync and IP Voice Media Streaming App stayed inactive for this test.

I checked that the publisher accepted a TCP connection on SIP port 5060 and that TFTP returned the first block of `ITLFile.tlv`. Registering two phones and placing a call is still a separate test. For what sent me back to that 2019 post in the first place, though, I now have a CUCM 15SU5 publisher I can log into, query, and shut down when I'm done testing.
