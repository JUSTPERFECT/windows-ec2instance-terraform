# Lookup the correct AMI based on the region specified
data "aws_ami" "amazon_windows_2012R2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2012-R2_RTM-English-64Bit-Base-*"]
  }
}

resource "aws_instance" "winrm" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    type     = "winrm"
    user     = "Administrator"
    password = "${var.admin_password}"
    # set from default of 5m to 10m to avoid winrm timeout
    timeout  = "30m"
  }

  instance_type = "t2.micro"
  ami           = "${data.aws_ami.amazon_windows_2012R2.image_id}"
iam_instance_profile="kingkongrole"
  # The name of our SSH keypair you've created and downloaded
  # from the AWS console.
  #
  # https://console.aws.amazon.com/ec2/v2/home?region=us-west-2#KeyPairs
  #
  key_name = "${var.key_name}"

  # Our Security group to allow WinRM access

  # Note that terraform uses Go WinRM which doesn't support https at this time. If server is not on a private network,
  # recommend bootstraping Chef via user_data.  See asg_user_data.tpl for an example on how to do that.
  user_data = <<EOF
<script>
  winrm quickconfig -q & winrm set winrm/config @{MaxTimeoutms="1800000"} & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"}
</script>
<powershell>
  netsh advfirewall firewall add rule name="WinRM in" protocol=TCP dir=in profile=any localport=5985 remoteip=any localip=any action=allow
  # Set Administrator password
  $admin = [adsi]("WinNT://./administrator, user")
  $admin.psbase.invoke("SetPassword", "${var.admin_password}")
</powershell>
EOF
provisioner "file" {
source ="test.json"
destination="C:\\test.json"
}
provisioner "file" {
source="test.ps1"
destination="C:\\test.ps1"
}
provisioner "remote-exec" {
inline = [
"powershell.exe -Executionpolicy Unrestricted -File C:\\test.ps1",
]
}
}
