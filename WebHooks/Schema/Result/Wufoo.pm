use utf8;
package WebHooks::Schema::Result::Wufoo;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WebHooks::Schema::Result::Wufoo

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");

=head1 TABLE: C<wufoo>

=cut

__PACKAGE__->table("wufoo");

=head1 ACCESSORS

=head2 entry_id

  data_type: 'text'
  is_nullable: 0

=head2 email

  data_type: 'text'
  is_nullable: 0

=head2 subscription

  data_type: 'text'
  is_nullable: 0

=head2 timestamp

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 form_url

  data_type: 'text'
  is_nullable: 0

=head2 date_created

  data_type: 'timestamp'
  is_nullable: 0

=head2 form_data

  data_type: 'text'
  is_nullable: 0

=head2 wc_status

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 wc_response

  data_type: 'text'
  is_nullable: 1

=head2 ip_address

  data_type: 'inet'
  is_nullable: 0

=head2 form_name

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "entry_id",
  { data_type => "text", is_nullable => 0 },
  "email",
  { data_type => "text", is_nullable => 0 },
  "subscription",
  { data_type => "text", is_nullable => 0 },
  "timestamp",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "form_url",
  { data_type => "text", is_nullable => 0 },
  "date_created",
  { data_type => "timestamp", is_nullable => 0 },
  "form_data",
  { data_type => "text", is_nullable => 0 },
  "wc_status",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "wc_response",
  { data_type => "text", is_nullable => 1 },
  "ip_address",
  { data_type => "inet", is_nullable => 0 },
  "form_name",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</entry_id>

=back

=cut

__PACKAGE__->set_primary_key("entry_id");


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-07-11 10:16:28
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xNSCTg3AR/N1FUEUuhFs9g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->table("webhooks.wufoo");

1;
