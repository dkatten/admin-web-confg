require 'pp'
require 'set'
require 'cgi'
require 'json'
require 'fileutils'
require File.join(File.dirname(__FILE__), '../../lib/pki_support')

# we'll attempt to load this to set up a hook for hostname/ip changes
begin
  require File.join(File.dirname(__FILE__), '../../admin-web-network-root/lib/network_support')
rescue LoadError
  # failure is, in fact, an option
end

if Object.const_defined?(:NetworkSupport)
  NetworkSupport::append_network_interface_changed_hook do
    PkiSupport::request_and_sign_certificate('renew')
  end
  NetworkSupport::append_hostname_changed_hook do
    PkiSupport::request_and_sign_certificate('renew')
  end
end

module Config
  module ConfigDetails
    module_dir = File.dirname(__FILE__)
    public_dir = File.join(module_dir, 'public')
    template_dir = File.join(module_dir, 'views')

    include gen_submodule_public(public_dir, '/config/config_details')
    include gen_submodule_render(template_dir)

    module Helpers
      # TODO This should probably be broken up into separate render methods, or
      # perhaps even converted to AJAX so that the various stages can be stepped
      # through without reloading the entire page
      def config_config_details_render(options = {})
        # supported options
        #   none

        config_path = '/var/ob/calibration_directory_and_file.txt'

        # branch 1: update certificate (update_certificate)
        if params.key?('page')  &&  params['page'] == 'update_certificate'
          rv = nil
          if params[:type] == 'oblong'
            rv = PkiSupport::verify_certificate(ca_path + '/ca.pem',
                                                ca_path + '/subordinate_ca.pem', nil,
                                                ca_path + '/private/subordinate_ca.key')
          end

          # Read certificate information, which is saved in "subordinate_ca.pem"
          # during initial installation. Note, "subordinate_ca.pem" once created
          # will not be replaced. Therefore, this information can be shared by
          # either Oblong or 3rd-party certificates.

          if rv.nil?
            cert = PkiSupport::get_certificate_info(ca_path + '/subordinate_ca.pem')
            if cert.nil?
              rv = "Unable to read the certificate of Subordinate CA at #{ca_path}/subordinate_ca.pem"
            else
              ip = PkiSupport::get_ip
              host_name = NetworkSupport::get_hostname
              common_name = PkiSupport::get_common_name
            end
          end

          if rv.nil?
            CertificateDetails::render(method(:erb), 'update_certificate.erb', {
              :domain_component1 => cert['domain_component1'],
              :domain_component2 => cert['domain_component2'],
              :organization_name => cert['subject_organization'],
              :organizational_unit_name => cert['subject_organizational_unit'],
              :country_name => cert['subject_country_name'],
              :sop_name => cert['subject_sop_name'],
              :locality_name => cert['subject_locality_name'],
              :common_name => common_name,
              :host_name => host_name,
              :ip_address => ip
            })
          else
            CertificateDetails::render(method(:erb), 'update_certificate.erb', {
              :error_string => "/#{params['page']} failure: #{rv}"
            })
          end

        # branch 2: install 3rd-party certificate (install_certificate)
        #   Note, removed as 3rd-party certificate is not supported.

        # branch 3: show certificate updated
        elsif params.key?('page')  &&  params['page'] == 'certificate_updated'
          CertificateDetails::render(method(:erb), 'certificate_updated.erb', {
            :restart_app => options[:restart_app],
            :restart_msg => options[:restart_msg]
          })

        # branch 4: show error page
        elsif params.key?('page')  &&  params['page'] == 'error'
          CertificateDetails::render(method(:erb), 'error.erb', {
            :error_string => CGI.unescape(params['val'])
          })

        # branch 5: display certificate signing request (display_csr)
        #   Note, removed as 3rd-party certificate is not supported.

        # branch 6: show current certificate
        elsif params.key?('page') == false
          rv = nil

          fp1 = PkiSupport::read_item(server_path + '/server.pem', 'x509', '-fingerprint')
          fp2 = PkiSupport::read_item(etc_path + '/server-certificate-chain.pem', 'x509', '-fingerprint')
          if fp1 == fp2  # This is Oblong signed certificate.
            rv = PkiSupport::verify_certificate(server_path + '/ca.pem',
                                                server_path + '/server.pem', nil,
                                                server_path + '/private/server.key')
          end

          CertificateDetails::render(method(:erb), 'certificate.erb', {
            :current_certificate => PkiSupport::get_certificate_info(etc_path + '/server-certificate-chain.pem'),
            :error_string => rv
          })

        # final: error
        else
          CertificateDetails::render(method(:erb), 'error.erb', {
            :error_string => 'incorrect reference'
          })
        end
      end
    end

    def self.registered(app)
      app.helpers CertificateDetails::Helpers

      app.post '/update_certificate' do  # update Oblong signed server certificate
                                     # or, create CSR to be signed by third-party

        # Note, use "*_temp.*" files and convert them to "*.*" files after it succeeds.

        rv = nil

        if params.has_key?('type')  &&  params['type'] != 'oblong'
          rv = "Updating third-party certificate is not supported."
        end

        params['type'] = 'oblong'

        rv = PkiSupport::request_and_sign_certificate(params['type'], params)

        if rv.nil?
          redirect to('/certificate?page=certificate_updated')
        else
          rv = "/update_certificate failure: #{rv}"
          redirect to("/certificate?page=error&val=#{CGI.escape(rv)}")
        end
      end


      app.post '/set_certificate_data' do
        PkiSupport::set_certificate_data("#{etc_path}/server-certificate-chain.pem")
      end
    end

  end
end
