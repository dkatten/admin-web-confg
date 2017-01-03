require 'open3'
require 'stringio'
require 'socket'
require 'rubygems'
require 'json'
#require File.join(File.dirname(__FILE__), '../../admin-web-network-root/lib/network_support')

begin
  require 'Pool'
rescue LoadError => e
  obj = JSON.parse(IO.popen('ob-version -y').readlines.join('\n'))
  x = obj['ob-prefix-dir'][0]
  $:.concat([
    "#{x}",
    "#{x}/lib",
    "#{x}/lib64",
    "#{x}/lib64/ruby",
    "#{x}/lib/ruby",
  ])
  require 'Pool'
end


module PkiSupport
  class << self


    def get_certificate_info(filename, type = 'x509')
      if File.exists?(filename)
        certificate = {}
        certificate['subject_country_name'] = read_item(filename, type, '-subject', '/C=')
        certificate['subject_sop_name'] = read_item(filename, type, '-subject', '/ST=')
        certificate['subject_locality_name'] = read_item(filename, type, '-subject', '/L=')
        certificate['subject_common_name'] = read_item(filename, type, '-subject', '/CN=')
        certificate['subject_organization'] = read_item(filename, type, '-subject', '/O=')
        certificate['subject_organizational_unit'] = read_item(filename, type, '-subject', '/OU=')
        certificate['serial_number'] = read_item(filename, type, '-serial')
        certificate['issuer_common_name'] = read_item(filename, type, '-issuer', '/CN=')
        certificate['issuer_organization'] = read_item(filename, type, '-issuer', '/O=')
        certificate['issuer_organizational_unit'] = read_item(filename, type, '-issuer', '/OU=')
        certificate['start_date'] = read_item(filename, type, '-startdate')
        certificate['end_date'] = read_item(filename, type, '-enddate')
        certificate['fingerprint'] = read_item(filename, type, '-fingerprint')

        # derive domain compnent
        dc = read_item(filename, type, '-subject').split('/DC=').drop(1)
        if ! dc.nil?  &&  ! dc.empty?
          certificate['domain_component1'] = dc[0].split('/').first
          certificate['domain_component2'] = dc[1].split('/').first
        else
          certificate['domain_component1'] = ''
          certificate['domain_component2'] = ''
        end

        certificate['subject_ip'] = get_ip
        certificate['subject_host_name'] = get_hostname

        return certificate
      end
      return nil
    end


    def read_certificate_authority_keyid(filename)
      stdin, stdout, stderr = Open3.popen3("openssl x509 -in #{filename} -certopt no_subject,no_header,no_version,no_serial,no_signame,no_validity,no_subject,no_issuer,no_pubkey,no_sigdump,no_aux -noout -text")
      found = false
      while line = stdout.gets
        if ! line.index('X509v3 Authority Key Identifier').nil?
          found = true
        else
          if found
            return line.strip
          end
        end
      end

      return nil
    end


    def read_certificate_subject_keyid(filename)
      stdin, stdout, stderr = Open3.popen3("openssl x509 -in #{filename} -certopt no_subject,no_header,no_version,no_serial,no_signame,no_validity,no_subject,no_issuer,no_pubkey,no_sigdump,no_aux -noout -text")
      found = false
      while line = stdout.gets
        if ! line.index('X509v3 Subject Key Identifier').nil?
          found = true
        else
          if found
            return line.strip
          end
        end
      end

      return nil
    end


    def read_item(filename, type, item, separator = '=')
      stdin, stdout, stderr = Open3.popen3('openssl', type, '-in', filename, '-noout', item)
      rv = stdout.gets  # note, only read one line
      unless rv.nil?
        if separator == '='
          return rv.partition('=').last.chomp
        else
          return rv.partition(separator).last.partition('/').first.chomp
        end
      end
      return ''
    end


    def verify_certificate(ca, pub, mid = nil, pri = nil)
      if ! File.exists?(ca)
        return "#{ca} not found"
      end

      cmd = "openssl verify -CAfile #{ca} "

      if ! mid.nil?
        if ! File.exists?(mid)
          return "#{mid} not found"
        end
        cmd.concat "-untrusted #{mid} "
      end

      if ! File.exists?(pub)
        return "#{pub} not found"
      end

      cmd.concat "#{pub}"

      rv = check_run(cmd, 'error ')
      if rv.nil?
        unless pri.nil?
          if ! File.exists?(pri)
            return "#{pri} not found"
          end
          prim = read_item(pri, 'rsa', '-modulus')
          pubm = read_item(pub, 'x509', '-modulus')
          if prim.empty?  ||  pubm.empty?  ||  prim != pubm
            return "modulus unmatch: #{prim} #{pubm}"
          end
        end
        return nil
      end

      return rv
    end


    def create_csr(path, args, public_csr_file, private_key_file)
      rv = check_run("(export HOME=#{path}; openssl req -verbose -new #{args} -out #{public_csr_file} -keyout #{private_key_file})")
      unless rv.nil?
        return rv
      end

      rv = check_run("chmod 400 #{private_key_file}")
      unless rv.nil?
        return rv
      end

      return nil
    end


    def create_conf(path, file, domain_component_1, domain_component_2, country_name, sop_name, locality_name, organization_name, organizational_unit_name, common_name, host_name, ip_address, key_size)
      text = <<-EOS
[ default ]
ca                      = server
dir                     = #{path}

[ req ]
default_bits            = #{key_size}
encrypt_key             = no
default_md              = sha1
utf8                    = yes
string_mask             = utf8only
prompt                  = no
distinguished_name      = req_dn
req_extensions          = v3_req

[ v3_req ]
subjectAltName          = @alt_names

[ req_dn ]
countryName             = "#{country_name}"
stateOrProvinceName     = "#{sop_name}"
localityName            = "#{locality_name}"
organizationName        = "#{organization_name}"
organizationalUnitName  = "#{organizational_unit_name}"
commonName              = "#{common_name}"
      EOS

      unless domain_component_1.empty?  ||  domain_component_2.empty?
        text = text + "0.domainComponent       = \"#{domain_component_1}\"\n"
        text = text + "1.domainComponent       = \"#{domain_component_2}\"\n"
      end

      text = text + "\n[ alt_names ]\n"

      n = 1
      text = text + "DNS.#{n}                   = \"#{common_name}\"\n"
      n = n + 1

      if host_name != common_name
        text = text + "DNS.#{n}                   = \"#{host_name}\"\n"
        n = n + 1
      end

      n = 1
      ip_address.each { |ip|
        text = text + "IP.#{n}                   = \"#{ip}\"\n"
        n = n + 1
      }

      begin
        File.open(file, 'w') { |f| f.write(text) }
      rescue => e
        return e.message
      end
      return nil
    end


    def display_csr(csr_file)
      File.read(csr_file)
    end


    def sign_csr(conf_file, csr_file, crt_file, to_whom, pwd_file = nil)
      if pwd_file.nil?
        rv = check_run("openssl ca -create_serial -batch -config #{conf_file} -in #{csr_file} -out #{crt_file} -extensions #{to_whom}_ext")
      else
        begin
          password = File.read(pwd_file)
          rv = check_run("openssl ca -create_serial -batch -config #{conf_file} -in #{csr_file} -out #{crt_file} -extensions #{to_whom}_ext -key #{password}")
        rescue => e
          return rv = e.message
        end
      end

      unless rv.nil?
        return 'sign CSR failed'  # do not use rv from check_run, otherwise it may reveal password
      end
      return nil
    end


    def check_run(cmd, watch_string = "")
      rv = `#{cmd} 2>&1`
      if $?.exitstatus != 0  ||  (! rv.nil?  &&  ! watch_string.empty?  &&  ! rv.index(watch_string).nil?)
        return "rv: #{rv}"
      end

      return nil
    end


    def convert_to_pem(crt_file, pem_file)
      rv = check_run("openssl x509 -in #{crt_file} -out #{pem_file}")
      unless rv.nil?
        return rv
      end
      return nil
    end


    def parse_certificate(block, n)
      certs = block.split('Certificate:').drop(1).map { |s| 'Certificate:' + s }
    end


    def execute_commands(arr)
      arr.each { |c|
        rv = check_run(c)
        unless rv.nil?
          return rv
        end
      }
      return nil
    end


    def clear_files(arr)
      arr.each { |f|
        if File.exists?(f)
          `rm -f #{f}`
        end
      }
    end


    def get_fqdn
      begin
        local_ip = get_public_ip
        addr = local_ip.chomp.split('.').map { |x| x.to_i }
        local_address = Socket.gethostbyaddr(addr.pack("CCCC")).first
      rescue => e
        return nil
      end
    end


    def get_public_ip
      interfaces = `netstat -i -a | awk '{ print $1 }' | grep -E 'eth0|eth1'`.split
      public_interface = interfaces[0]
      if interfaces.size == 2
        text = File.read('/etc/oblong/nic-convention.conf')
        data = Hash[text.scan(/(\S+)\s*=\s*"([^"]+)/)]
        public_interface = (data["PRIVATE_INTERFACE"] == "eth0") ? "eth1" : "eth0"
      end
      `ifconfig #{public_interface} | awk -F: '/inet addr:/ {print $2}' | awk '{ print $1 }'`.strip
    end


    def get_ip
      ip = []
      IO.popen('ip -o -4 addr | awk \'!/^[0-9]*: ?lo|link\/ether/ {gsub("/", " "); print $4}\'').each do |line|
        ip << line.chomp
      end
      return ip    # local_ip = UDPSocket.open { |s| s.connect("64.233.187.99", 1); s.addr.last }
    end


    def get_hostname(opts = {})
      opts[:file] ||= '/etc/hostname'
      File.open(opts[:file], 'r') { |f| f.read }.strip
    end


    def get_common_name
      common_name = get_fqdn
      if common_name.nil?  ||  common_name.split('.').last == 'local'  # This indicates FQDN failure, then we use host_name as common_name.
        common_name = get_hostname
      end
      common_name
    end


    def set_certificate_data(crt_file)
      # After certificate installation, drop a request to write "cert_data" in "mip.conf".
      issued_to = read_item(crt_file, "x509", '-subject', '/CN=')
      organization = read_item(crt_file, "x509", '-subject', '/O=')
      issued_by = read_item(crt_file, "x509", '-issuer', '/O=')
      issued_on = read_item(crt_file, "x509", '-startdate')
      expires_on = read_item(crt_file, "x509", '-enddate')
      fingerprint = read_item(crt_file, "x509", '-fingerprint')

      rv = nil

      _hose = nil
      begin
        _hose = Plasma::Pool.participate "m2m-settings-into-mz"
      rescue => e
        rv = 'Failure in Plasma::Pool.participate "m2m-settings-into-mz": ' + e.message
      end

      if rv.nil?
        unless _hose.nil?
          begin
            p = Plasma::Protein.new( ["mezzanine", "prot-spec v2.0", "request", "admin-set-cert"],
                             {"issued_to" => issued_to,
                              "organization" => organization,
                              "issued_by" => issued_by,
                              "issued_on" => issued_on,
                              "expires_on" => expires_on,
                              "fingerprint" => fingerprint}
                           )
            _hose.deposit p
          rescue => e
            rv = 'Failure in deposit: ' + e.message
          end
          _hose.withdraw
        end
      else
        rv = nil    # ignore this error, if pool "m2m-settings-into-mz" does not exist (e.g., corkboard only)
      end           # then just don't deposit (Bug 11699)

      return rv
    end


    def verify_csr(server_path, csr)
      csr_file = "#{server_path}/#{csr}"
      pri = "#{server_path}/private/server_temp.key"

      if ! File.exists?(csr_file)
        return false
      end

      csrm = read_item(csr_file, 'req', '-modulus')
      prim = read_item(pri, 'rsa', '-modulus')
      if csrm.empty?  ||  prim.empty?  ||  csrm != prim
        return false
      end

      return true
    end


    def request_and_sign_certificate(type, params = nil)

      # Note,
      #   type == "oblong"  ==> sign
      #   type == "renew"   ==> sign Oblong
      #     So, if previously a third-party certificate, it will be replaced by Oblong.
      #   type == "third-party" ==> create CSR and return

      rv = nil

      etc_path ||= '/etc/oblong'
      ca_path ||= '/etc/oblong/pki/subordinate_ca'
      server_path ||= '/etc/oblong/pki/server'

      # create CSR
      if type == 'renew'
        cert = get_certificate_info(ca_path + '/subordinate_ca.pem')  # Note, because we renew cert based on Oblong, so we should read cert info from Oblong's CA.
        cert['subject_common_name'] = get_common_name  # update FQDN
        rv = create_conf("#{server_path}", "#{server_path}/conf/server.conf", cert['domain_component1'], cert['domain_component2'],
                         cert['subject_country_name'], cert['subject_sop_name'], cert['subject_locality_name'], cert['subject_organization'], cert['subject_organizational_unit'],
                         cert['subject_common_name'], cert['subject_host_name'], cert['subject_ip'], '4096')
      else
        rv = create_conf("#{server_path}", "#{server_path}/conf/server.conf", params['domain_component1'], params['domain_component2'],
                         params['country_name'], params['sop_name'], params['locality_name'], params['organization_name'], params['organizational_unit_name'],
                         params['common_name'], params['host_name'], params['ip_address'], params['key_size'])
      end

      if rv.nil?
        rv = create_csr("#{server_path}",
                        "-nodes -config #{server_path}/conf/server.conf",
                        "#{server_path}/server.csr",
                        "#{server_path}/private/server_temp.key")
        if rv.nil?
          rv = execute_commands(["chmod 400 #{server_path}/private/server_temp.key"])
        end
      end

      if rv.nil?
        if type == 'oblong'  ||  type == 'renew'  # for oblong, sign and update
          rv = sign_csr(ca_path + '/conf/subordinate_ca.conf',
                        server_path + '/server.csr',
                        server_path + '/server_temp.crt',
                        'server')
          if rv.nil?
            rv = convert_to_pem(server_path + '/server_temp.crt', server_path + '/server_temp.pem')
            if rv.nil?
              rv = execute_commands(["cp #{server_path}/server_temp.pem #{server_path}/server.pem",
                                     "cp #{server_path}/private/server_temp.key #{server_path}/private/server.key",
                                     "chmod 400 #{server_path}/private/server.key",
                                     "cat #{server_path}/server.pem #{ca_path}/subordinate_ca.pem #{ca_path}/signing_ca.pem > #{etc_path}/server-certificate-chain.pem",
                                     "cp #{server_path}/private/server.key #{etc_path}/server-private-key.pem",
                                     "cp #{etc_path}/server-certificate-chain.pem #{etc_path}/client-certificate-chain.pem",
                                     "cp #{etc_path}/server-private-key.pem #{etc_path}/client-private-key.pem",
                                     "rm -f #{server_path}/server.csr"])

              # Send request to mip server to write certificate information to "cert-data".
              if rv.nil?
                rv = set_certificate_data("#{server_path}/server.pem")
              end
            end
          end
        end
      end

      unless rv.nil?
        clear_files([server_path + '/server.csr',
                     server_path + '/private/server_temp.key',
                     server_path + '/server_temp.crt',
                     server_path + '/server_temp.pem'])
        rv = "/update_certificate failure: #{rv}"
      end
      return rv
    end

  end
end
