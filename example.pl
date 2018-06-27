use FindBin;
use lib "$FindBin::Bin/../lib";

use Search::Elasticsearch;
use JSON;
use Data::Dumper;
use utf8;

#use DateTime::Format::Strptime;
#use Mojo::Util qw(trim);

#use Rplus::Model::Result;
#use Rplus::Util::Realty qw(save_data_to_all);
#use Mojo::Log;
#use Rplus::Modern;
#use Rplus::Class::Media;
#use Rplus::Class::Interface;
#use Rplus::Class::UserAgent;

use JSON;
use Data::Dumper;

no warnings 'experimental';


my $media_name = 'avito';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M');
my $ua;
my $META = {
    params => {
        dict => {
            bathrooms => {
                '__field__' => 'bathroom_id',
                '^с\\/у\\s+смежн\\.?$' => 8,
                '^смежн\\.?\\s+с\\/у$' => 8,
                '^с\\/у\\s+разд\\.?$' => 3,
                '^без\\s+удобств$' => 1,
                '^с\\/у\\s+совм\\.?$' => 8
            },
            balconies => {
                '__field__' => 'balcony_id',
                '^б\\/з$' => 5,
                '^б\\/балк\\.?$' => 1,
                '^2\\s+лодж\\.?$' => 8,
                '^б\\/б$' => 1,
                '^балк\\.?$' => 2,
                '^лодж\\.?$' => 3,
                '^2\\s+балк\\.?$' => 7,
                '^л\\/з$' => 6
            },
            ap_schemes => {
                '__field__' => 'ap_scheme_id',
                '^улучшенная\\.?$' => 3,
                '^хрущевка\\.?$' => 2,
                '^хрущовка\\.?$' => 2,
                '^общежитие' => 6,
                '^индивидуальная\\.?$' => 6,
                '^индивидуальная\\.?\\s+планировка\\.?$' => 5,
                '^улучшенная\\.?$' => 3,
                '^брежневка\\.?$' => 3,
                '^новая\\.?\\s+планировка\\.?$' => 4,
                '^сталинка\\.?$' => 1,
                '^(?:улучшенная\\.?\\s+планировка\\.?)|(?:планировка\\.?\\s+улучшенная\\.?)|(?:улучшенная\\.)$' => 3,
                '^хрущ\\.?$' => 2,
                '^общежити' => 6,
                '^инд\\.?\\s+план\\.?$' => 5,
                '^брежн\\.?$' => 3,
                '^нов\\.?\\s+план\\.?$' => 4,
                '^стал\\.?$' => 1,
                '^(?:улучш\\.?\\s+план\\.?)|(?:план\\.?\\s+улучш\\.?)|(?:улучш\\.)$' => 3
            },
            house_types => {
                '__field__' => 'house_type_id',
                '^кирп\\.?$' => 1,
                '^монолит.+?\\-кирп\\.?$' => 7,
                '^монолитн?\\.?$' => 2,
                '^пан\\.?$' => 3,
                '^брус$' => 5,
                '^дерев\\.?$' => 4
            },
            conditions => {
                '__field__' => 'condition_id',
                '^соц\\.?\\s+ремонт$' => 2,
                '^тр\\.?\\s+ремонт$' => 6,
                'еврорем' => 4,
                '^отл\\.?\\s+сост\\.?$' => 12,
                '^хор\\.?\\s+сост\\.?$' => 11,
                '^сост\\.?\\s+хор\\.?$' => 11,
                '^удовл\\.?\\s+сост\\.?$' => 9,
                '^после\\s+строит\\.?$' => 1,
                '^сост\\.?\\s+отл\\.?$' => 12,
                '^дизайнерский ремонт$' => 5,
                '^п\\/строит\\.?$' => 1,
                '^сост\\.?\\s+удовл\\.?$' => 9,
                '^т\\.\\s*к\\.\\s*р\\.$' => 7,
                '^сделан ремонт$' => 3,
                '^норм\\.?\\s+сост\\.?$' => 10,
                '^треб\\.?\\s+ремонт$' => 6,
                '^сост\\.?\\s+норм\\.?$' => 10
            },
            room_schemes => {
                '__field__' => 'room_scheme_id',
                '^комн\\.?\\s+разд\\.?$' => 3,
                'икарус' => 5,
                '^разд\\.?\\s+комн\\.?$' => 3,
                '^смежн\\.?\\s+комн\\.?$' => 4,
                '^комн\\.?\\s+смежн\\.?$' => 4,
                '^кухня\\-гостиная$' => 2,
                '^студия$' => 1
            }
        },
    }
};

get_item('khv', '/habarovsk/kvartiry/2-k_kvartira_54.8_m_318_et._593607544');
# update();

sub update {
    for(my $i=1; $i<=1200; $i++){
        my %full_query = (
            index => 'rplus-import',
            type => 'offer',
            body  => {
                query => {
                    bool => {
                        must => []
                    }
                },
                size  => 100,
                from => 100 * $i
            }
        );
        my $e = Search::Elasticsearch->new(nodes  => 'import.rplusmgmt.com:9200');
        my $results = $e->search(%full_query);
        #say  $results->{hits}->{hits};
        foreach my $val (@{$results->{hits}->{hits}}){
            foreach my $ph(@{$val->{_source}->{owner_phones}}){
                $ph =~ s/\+|\(|\)|-|\s//g;
            }

            my $rez = $e->index(
                index   => 'rplus-import',
                 type    => 'offer',
                 id => $val->{_id},
                 body    => {
                     %{$val->{_source}}
                 }
             );
             say  $rez;
        }
    }
}

sub get_item {
    my ($location, $item_url) = @_;

    say  ('loading ' . $media_name . ' - ' . $location . ' - ' . $item_url);
    my $data = _get_item($location, $item_url);

    my $id_it = save_data_to_all($data, $media_name, $location);
    say ('save new avito '.$id_it);
}

sub _get_item {
    my ($location, $item_url) = @_;

    $media_data = Rplus::Class::Media->instance()->get_media('avito', $location);;


    my $data = {
        source_media => $media_name,
        source_url => $media_data->{site_url} . $item_url,
        type_code => 'other',
        offer_type_code => 'sale',
        add_date => ''
    };

    parse_adv($data, $item_url);

    return $data;
}

sub parse_adv {
    my ($data, $item_url) = @_;

    my $source_url = $media_data->{site_url} . $item_url;

    my $res;
    my $counter = 0;
    while(1){
        $ua = Rplus::Class::UserAgent->new(Rplus::Class::Interface->instance()->get_interface());
        $res = $ua->get_res($source_url, [
            Host => $media_data->{host},
            Referer => $media_data->{site_url}
        ]);
        if(!$res && $counter < 10){
            sleep(5);
            $counter = $counter + 1;
        } else{
            last;
        }
    }

    my $dom = $res->dom;
    my $id_data_str = '';
    if( $dom->at('div[class="title-info-metadata"]')){
        $id_data_str = $dom->at('div[class="title-info-metadata"]')->find('div[class="title-info-metadata-item"]')->first->text;
    }

    my $item_id;
    if ($id_data_str =~ /№ (\d+),/i) {
        $item_id = $1 * 1;
    }

    if ($id_data_str =~ /размещено (.+)/i) {
        my $dt = _parse_date($1);
        $data->{add_date} = $dt->format_cldr("yyyy-MM-dd'T'HH:mm:ssZ");
    }

    # тип недвижимости и тип предложения
    my $breadcrumbs = lc($dom->at('div[class~="breadcrumbs"]')->all_text);

    say $breadcrumbs;

    if ($breadcrumbs =~ /сдам/) {
        $data->{offer_type_code} = 'rent';
        if ($breadcrumbs =~ /посуточно/) {
            $data->{rent_type} = 'short';
        }
    } else {
        $data->{offer_type_code} = 'sale';
    }

    if ($breadcrumbs =~ /квартир/) {
        $data->{type_code} = 'apartment';
    } elsif ($breadcrumbs =~ /таунхаус/) {
        $data->{type_code} = 'townhouse';
    } elsif ($breadcrumbs =~ /малосем/) {
        $data->{type_code} = 'apartment_small';
    } elsif ($breadcrumbs =~ /комнат/) {
        $data->{type_code} = 'room';
    } elsif ($breadcrumbs =~ /дом/) {
        $data->{type_code} = 'house';
    } elsif ($breadcrumbs =~ /дач/) {
        $data->{type_code} = 'dacha';
    } elsif ($breadcrumbs =~ /коттедж/) {
        $data->{type_code} = 'cottage';
    } elsif ($breadcrumbs =~ /участок/) {
        $data->{type_code} = 'land';
    } elsif ($breadcrumbs =~ /гараж/) {
        $data->{type_code} = 'garage';
    } elsif ($breadcrumbs =~ /торговое помещение/) {
        $data->{type_code} = 'market_place';
    } elsif ($breadcrumbs =~ /магазин/) {
        $data->{type_code} = 'market_place';
    } elsif ($breadcrumbs =~ /павильон/) {
        $data->{type_code} = 'market_place';
    } elsif ($breadcrumbs =~ /офис/) {
        $data->{type_code} = 'office_place';
    } elsif ($breadcrumbs =~ /нежилое помещение/) {
        $data->{type_code} = 'gpurpose_place';
    } elsif ($breadcrumbs =~ /склад/) {
        $data->{type_code} = 'warehouse_place';
    } elsif ($breadcrumbs =~ /производственное помещение/) {
        $data->{type_code} = 'production_place';
    } elsif ($breadcrumbs =~ /помещение свободного назначения/) {
        $data->{type_code} = 'gpurpose_place';
    } elsif ($breadcrumbs =~ /помещение/) {
        $data->{type_code} = 'gpurpose_place';
    }

    # описание
    if ($dom->at('div[class~="item-description-text"]')) {
        $data->{'source_media_text'} = $dom->at('div[class~="item-description-text"]')->all_text;
    }

    # заголовок осн. информация
    my $main_title = $dom->at('h1[class="title-info-title"]')->all_text;
    $main_title = trim $main_title;
    given($data->{type_code}) {
        when ('room') {
            my @bp = map {trim $_} grep { $_ && length($_) > 1 } split /[,()]/, $main_title;
            # комната м2 бла...
            if ($bp[0] =~ /^.*?(\d{1,}).*?$/) {
                $data->{'square_total'} = $1;
            }
            # d/d эт.
            if (defined $bp[1] && $bp[1] =~ /^(\d{1,2})\/(\d{1,2}).*?$/) {
                if ($2 >= $1) {
                    $data->{'floor'} = $1;
                    $data->{'floors_count'} = $2;
                }
            }
        }
        when ('apartment') {
            my @bp = map {trim $_} grep { $_ && length($_) > 1 } split /[,()]/, $main_title;
            # d-к квратира.
            if ($bp[0] =~ /^(\d{1,}).*?$/) {
                $data->{'rooms_count'} = $1;
            }
            # d м2.
            if ($bp[1] =~ /^(\d{1,}).*?$/) {
                $data->{'square_total'} = $1;
            }
            # d/d эт.
            if ($bp[2] =~ /^(\d{1,2})\/(\d{1,2}).*?$/) {
                if ($2 >= $1) {
                    $data->{'floor'} = $1;
                    $data->{'floors_count'} = $2;
                }
            }
        }
        when ('house') {
            given($main_title) {
                when (/дом/i) {
                }
                when (/коттедж/i) {
                    $data->{'type_code'} = 'cottage';
                }
                when (/дача/i) {
                    $data->{'type_code'} = 'land';
                }
                # wtf
                default {
                    say 'bla!';
                }
            }

            # d м2 d сот || d м2
            if ($main_title !~ /участке/) {
                if ($main_title =~ /^.*?(\d{1,}).*?$/) {
                    $data->{'square_total'} = $1;
                }
            } elsif ($main_title =~ /^.*?(\d{1,}).*?(\d{1,}).*?$/) {
                $data->{'square_total'} = $1;
                $data->{'square_land'} = $2;
                $data->{'square_land_type'} = 'ar';
            }
        }
        when ('land') {
            if ($main_title =~ /(\d+(?:,\d+)?)\s+кв\.\s*м/) {
                $main_title =~ s/\s//;
                if ($main_title =~ /^(\d{1,}).*?$/) {
                    $data->{'square_land'} = $1;
                }
            } elsif ($main_title =~ s/(\d+)\s+сот\.?//) {
                $data->{'square_land'} = $1;
                $data->{'square_land_type'} = 'ar';
            } elsif ($main_title =~ s/(\d(?:,\d+)?)\s+га//) {
                $data->{'square_land'} = $1 =~ s/,/./r;
                $data->{'square_land_type'} = 'hectare';
            }
        }
        default {}
    }

    #Основная информация
    $dom->find('li[class="item-params-list-item"]')->each (sub {
        my $value = $_->text;
        my $head = lc($_->find('span')->first->text);
        if($head =~ /количество комнат/){
            if($value =~ /студи/){
                $data->{'rooms_count'} = 1;
            } else {
                $data->{'rooms_count'} = trim($value =~ s/-комнат(.)+//r);
            }
        } elsif ($head =~ /этажей в доме/){
            $data->{'floors_count'} = trim($value);
        } elsif ($head =~ /этаж/){
            $data->{'floor'} = trim($value);
        } elsif ($head =~ /общая площадь/){
             $data->{'square_total'} = trim($value =~ s/\sм(.)+//r);
        } elsif ($head =~ /площадь кухни/){
             $data->{'square_kitchen'} = trim($value =~ s/\sм(.)+//r);
        } elsif ($head =~ /жилая площадь/){
             $data->{'square_living'} = trim($value =~ s/\sм(.)+//r);
        } elsif ($head =~ /площадь дома/){
             $data->{'square_total'} = trim($value =~ s/\sм(.)+//r);
        } elsif ($head =~ /площадь участка/){
             $data->{'square_land_type'} = 'ar';
             $data->{'square_land'} = trim($value =~ s/\sсот(.)+//r);
        } elsif ($head =~ /площадь/){
            if($data->{'type_code'} eq 'land'){
                $data->{'square_land_type'} = 'ar';
                $data->{'square_land'} = trim($value =~ s/\sсот(.)+//r);
            } else{
                $data->{'square_total'} = trim($value =~ s/\sм(.)+//r);
            }
        } elsif ($head =~ /(тип дома)|(материал стен)/){
            given ($value) {
                when (/кирпич/) {
                    $data->{house_type_id} = 1;
                }
                when (/панельный/ || /панел/) {
                    $data->{house_type_id} = 3;
                }
                #when (/блочный/ || /газобл/ || /пенобл/) {
                #    return 3;
                #}
                when (/монолитный/) {
                    $data->{house_type_id} = 2;
                }
                when (/деревянный/ || /брус/ || /бревн/) {
                    $data->{house_type_id} = 4;
                }
            }
        }
    });


    # Разделим остальную часть обявления на части и попытаемся вычленить полезную информацию
    if ($data->{'source_media_text'}) {
        my @bp = map {trim $_} grep { $_ && length($_) > 1 } split /[,()]/, $data->{'source_media_text'};
        for my $el (@bp) {
            # Этаж/этажность
            if ($el =~ /^(\d{1,2})\/(\d{1,2})$/) {
                if ($2 > $1) {
                    $data->{'floor'} = $1;
                    $data->{'floors_count'} = $2;
                }
                next;
            }

            for my $k (keys %{$META->{'params'}->{'dict'}}) {
                my %dict = %{$META->{'params'}->{'dict'}->{$k}};
                my $field = delete $dict{'__field__'};
                for my $re (keys %dict) {
                    if ($el =~ /$re/i) {
                        $data->{$field} = $dict{$re};
                        last;
                    }
                }
            }
        }
    }

    # цена в рублях, переведем в тыс.
    if ($dom->at('span[class~="price-value-string"]')) {
        my $price = $dom->at('span[class~="price-value-string"]')->text;
        $price =~s/\s//g;
        if ($price =~ /^(\d{1,}).*?$/) {
            $data->{'owner_price'} = $1 / 1000;
        }
    }

    # адрес
    # нас пункт
    if ($dom->at('meta[itemprop="addressLocality"]')) {
        $data->{locality} = $dom->at('meta[itemprop="addressLocality"]')->attr('content');
    }

    # адр
    if ($dom->find('span[itemprop="streetAddress"]')->first) {
        $data->{address} = $dom->find('span[itemprop="streetAddress"]')->first->all_text;
    }

    my @owner_phones;
    my $item_phone = '';
    my $pkey = '';
    $dom->find('script')->each(sub{
        if ($_->all_text =~ /item.phone = '(.+?)'/) {
            $item_phone = $1;
        }
    });

    $pkey = _phone_demixer($item_id * 1, $item_phone);

    sleep $media_data->{pause};

    my $m_url = 'https://m.avito.ru' . $item_url;

    $ua->get_res($m_url, [
        Host => 'm.avito.ru',
        Referer => $media_data->{site_url},
    ]);

    my $mr = $ua->get_res($m_url . '/phone/' . $pkey . '?async', [
        Host => 'm.avito.ru',
        Referer => $m_url,
        Accept => 'application/json, text/javascript, */*; q=0.01'
    ]);
    if ($mr && $mr->json) {
         my $phone_str = $mr->json->{phone};
        for my $x (split /[.,;:]/, $phone_str) {
            push @owner_phones, $x;
        }
    }
    $data->{'owner_phones'} = \@owner_phones;

    my $seller_name = $dom->find('div[class~="seller-info-prop"]')->first->text;

    if ($seller_name =~ /агентство/i) {
        my $seller = $dom->find('div[class="seller-info-name"] a')->first->text;
        $data->{mediator_company} = $seller;
    } else {
        my $seller_name = $dom->find('div[class="seller-info-col"]')->first->text;
        if ($seller_name =~ /агентство/i) {
            $data->{mediator_company} = $dom->find('div[class="seller-info-col"]')->first->find('a')->first->text;
        }
    }

    # вытащим фото
    my @photos;
    $dom->find('meta[property="og:image"]')->each (sub {
        unless ($_->{content} =~ /logo/) {
            my $img_url = $_->{content};
            push @photos, $img_url;
        }
    });
    $data->{photo_url} = \@photos;

    return $data;
}

sub _phone_demixer {
    my ($id, $key) = @_;

    my @parts = $key =~ /[0-9a-f]+/g;

    my $mixed = join '', $id % 2 == 0 ? reverse @parts : @parts;
    my $s = length $mixed;
    my $r = '';
    my $k;

    for($k = 0; $k < $s; ++ $k) {
        if( $k % 3 == 0 ) {
            $r .= substr $mixed, $k, 1;
        }
    }

    return $r;
}

sub _parse_date {
    my $date = lc(shift);

    my $res;
    my $dt_now = DateTime->now();
    my $year = $dt_now->year();
    my $mon = $dt_now->month();
    my $mday = $dt_now->mday();

    if ($date =~ /сегодня в (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        if ($res > $dt_now) {
            # substr 1 day
            #$res->subtract(days => 1);
        }
    } elsif ($date =~ /вчера в (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        # substr 1 day
        $res->subtract(days => 1);
    } elsif ($date =~ /(\d+) (\w+) в (\d{1,2}):(\d{1,2})/) {
        my $a_mon = _month_num($2);
        my $a_year = $year;
        if ($a_mon > $mon) { $a_year -= 1; }
        $res = $parser->parse_datetime("$a_year-$a_mon-$1 $3:$4");
    } else {
        $res = $dt_now;
    }

    return $res;
}

sub _month_num {
    my $month_str = lc(shift);

    given ($month_str) {
        when (/янв/) {
            return 1;
        }
        when (/фев/) {
            return 2;
        }
        when (/мар/) {
            return 3;
        }
        when (/апр/) {
            return 4;
        }
        when (/мая/) {
            return 5;
        }
        when (/июн/) {
            return 6;
        }
        when (/июл/) {
            return 7;
        }
        when (/авг/) {
            return 8;
        }
        when (/сен/) {
            return 9;
        }
        when (/окт/) {
            return 10;
        }
        when (/ноя/) {
            return 11;
        }
        when (/дек/) {
            return 12;
        }
    }
    return 0;
}

1;
use JSON;
use Data::Dumper;

no warnings 'experimental';


my $media_name = 'avito';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M');
my $ua;
my $META = {
    params => {
        dict => {
            bathrooms => {
                '__field__' => 'bathroom_id',
                '^с\\/у\\s+смежн\\.?$' => 8,
                '^смежн\\.?\\s+с\\/у$' => 8,
                '^с\\/у\\s+разд\\.?$' => 3,
                '^без\\s+удобств$' => 1,
                '^с\\/у\\s+совм\\.?$' => 8
            },
            balconies => {
                '__field__' => 'balcony_id',
                '^б\\/з$' => 5,
                '^б\\/балк\\.?$' => 1,
                '^2\\s+лодж\\.?$' => 8,
                '^б\\/б$' => 1,
                '^балк\\.?$' => 2,
                '^лодж\\.?$' => 3,
                '^2\\s+балк\\.?$' => 7,
                '^л\\/з$' => 6
            },
            ap_schemes => {
                '__field__' => 'ap_scheme_id',
                '^улучшенная\\.?$' => 3,
                '^хрущевка\\.?$' => 2,
                '^хрущовка\\.?$' => 2,
                '^общежитие' => 6,
                '^индивидуальная\\.?$' => 6,
                '^индивидуальная\\.?\\s+планировка\\.?$' => 5,
                '^улучшенная\\.?$' => 3,
                '^брежневка\\.?$' => 3,
                '^новая\\.?\\s+планировка\\.?$' => 4,
                '^сталинка\\.?$' => 1,
                '^(?:улучшенная\\.?\\s+планировка\\.?)|(?:планировка\\.?\\s+улучшенная\\.?)|(?:улучшенная\\.)$' => 3,
                '^хрущ\\.?$' => 2,
                '^общежити' => 6,
                '^инд\\.?\\s+план\\.?$' => 5,
                '^брежн\\.?$' => 3,
                '^нов\\.?\\s+план\\.?$' => 4,
                '^стал\\.?$' => 1,
                '^(?:улучш\\.?\\s+план\\.?)|(?:план\\.?\\s+улучш\\.?)|(?:улучш\\.)$' => 3
            },
            house_types => {
                '__field__' => 'house_type_id',
                '^кирп\\.?$' => 1,
                '^монолит.+?\\-кирп\\.?$' => 7,
                '^монолитн?\\.?$' => 2,
                '^пан\\.?$' => 3,
                '^брус$' => 5,
                '^дерев\\.?$' => 4
            },
            conditions => {
                '__field__' => 'condition_id',
                '^соц\\.?\\s+ремонт$' => 2,
                '^тр\\.?\\s+ремонт$' => 6,
                'еврорем' => 4,
                '^отл\\.?\\s+сост\\.?$' => 12,
                '^хор\\.?\\s+сост\\.?$' => 11,
                '^сост\\.?\\s+хор\\.?$' => 11,
                '^удовл\\.?\\s+сост\\.?$' => 9,
                '^после\\s+строит\\.?$' => 1,
                '^сост\\.?\\s+отл\\.?$' => 12,
                '^дизайнерский ремонт$' => 5,
                '^п\\/строит\\.?$' => 1,
                '^сост\\.?\\s+удовл\\.?$' => 9,
                '^т\\.\\s*к\\.\\s*р\\.$' => 7,
                '^сделан ремонт$' => 3,
                '^норм\\.?\\s+сост\\.?$' => 10,
                '^треб\\.?\\s+ремонт$' => 6,
                '^сост\\.?\\s+норм\\.?$' => 10
            },
            room_schemes => {
                '__field__' => 'room_scheme_id',
                '^комн\\.?\\s+разд\\.?$' => 3,
                'икарус' => 5,
                '^разд\\.?\\s+комн\\.?$' => 3,
                '^смежн\\.?\\s+комн\\.?$' => 4,
                '^комн\\.?\\s+смежн\\.?$' => 4,
                '^кухня\\-гостиная$' => 2,
                '^студия$' => 1
            }
        },
    }
};

get_item('khv', '/habarovsk/kvartiry/2-k_kvartira_54.8_m_318_et._593607544');
# update();

sub update {
    for(my $i=1; $i<=1200; $i++){
        my %full_query = (
            index => 'rplus-import',
            type => 'offer',
            body  => {
                query => {
                    bool => {
                        must => []
                    }
                },
                size  => 100,
                from => 100 * $i
            }
        );
        my $e = Search::Elasticsearch->new(nodes  => 'import.rplusmgmt.com:9200');
        my $results = $e->search(%full_query);
        #say  $results->{hits}->{hits};
        foreach my $val (@{$results->{hits}->{hits}}){
            foreach my $ph(@{$val->{_source}->{owner_phones}}){
                $ph =~ s/\+|\(|\)|-|\s//g;
            }

            my $rez = $e->index(
                index   => 'rplus-import',
                 type    => 'offer',
                 id => $val->{_id},
                 body    => {
                     %{$val->{_source}}
                 }
             );
             say  $rez;
        }
    }
}

sub get_item {
    my ($location, $item_url) = @_;

    say 'loading ' . $media_name . ' - ' . $location . ' - ' . $item_url;
    my $data = _get_item($location, $item_url);

    my $id_it = save_data_to_all($data, $media_name, $location);
    say 'save new avito '.$id_it;
}

sub _get_item {
    my ($location, $item_url) = @_;

    $media_data = Rplus::Class::Media->instance()->get_media('avito', $location);;


    my $data = {
        source_media => $media_name,
        source_url => $media_data->{site_url} . $item_url,
        type_code => 'other',
        offer_type_code => 'sale',
        add_date => ''
    };

    parse_adv($data, $item_url);

    return $data;
}

sub parse_adv {
    my ($data, $item_url) = @_;

    my $source_url = $media_data->{site_url} . $item_url;

    my $res;
    my $counter = 0;
    while(1){
        $ua = Rplus::Class::UserAgent->new(Rplus::Class::Interface->instance()->get_interface());
        $res = $ua->get_res($source_url, [
            Host => $media_data->{host},
            Referer => $media_data->{site_url}
        ]);
        if(!$res && $counter < 10){
            sleep(5);
            $counter = $counter + 1;
        } else{
            last;
        }
    }

    my $dom = $res->dom;
    my $id_data_str = '';
    if( $dom->at('div[class="title-info-metadata"]')){
        $id_data_str = $dom->at('div[class="title-info-metadata"]')->find('div[class="title-info-metadata-item"]')->first->text;
    }

    my $item_id;
    if ($id_data_str =~ /№ (\d+),/i) {
        $item_id = $1 * 1;
    }

    if ($id_data_str =~ /размещено (.+)/i) {
        my $dt = _parse_date($1);
        $data->{add_date} = $dt->format_cldr("yyyy-MM-dd'T'HH:mm:ssZ");
    }

    # тип недвижимости и тип предложения
    my $breadcrumbs = lc($dom->at('div[class~="breadcrumbs"]')->all_text);

    say $breadcrumbs;

    if ($breadcrumbs =~ /сдам/) {
        $data->{offer_type_code} = 'rent';
        if ($breadcrumbs =~ /посуточно/) {
            $data->{rent_type} = 'short';
        }
    } else {
        $data->{offer_type_code} = 'sale';
    }

    if ($breadcrumbs =~ /квартир/) {
        $data->{type_code} = 'apartment';
    } elsif ($breadcrumbs =~ /таунхаус/) {
        $data->{type_code} = 'townhouse';
    } elsif ($breadcrumbs =~ /малосем/) {
        $data->{type_code} = 'apartment_small';
    } elsif ($breadcrumbs =~ /комнат/) {
        $data->{type_code} = 'room';
    } elsif ($breadcrumbs =~ /дом/) {
        $data->{type_code} = 'house';
    } elsif ($breadcrumbs =~ /дач/) {
        $data->{type_code} = 'dacha';
    } elsif ($breadcrumbs =~ /коттедж/) {
        $data->{type_code} = 'cottage';
    } elsif ($breadcrumbs =~ /участок/) {
        $data->{type_code} = 'land';
    } elsif ($breadcrumbs =~ /гараж/) {
        $data->{type_code} = 'garage';
    } elsif ($breadcrumbs =~ /торговое помещение/) {
        $data->{type_code} = 'market_place';
    } elsif ($breadcrumbs =~ /магазин/) {
        $data->{type_code} = 'market_place';
    } elsif ($breadcrumbs =~ /павильон/) {
        $data->{type_code} = 'market_place';
    } elsif ($breadcrumbs =~ /офис/) {
        $data->{type_code} = 'office_place';
    } elsif ($breadcrumbs =~ /нежилое помещение/) {
        $data->{type_code} = 'gpurpose_place';
    } elsif ($breadcrumbs =~ /склад/) {
        $data->{type_code} = 'warehouse_place';
    } elsif ($breadcrumbs =~ /производственное помещение/) {
        $data->{type_code} = 'production_place';
    } elsif ($breadcrumbs =~ /помещение свободного назначения/) {
        $data->{type_code} = 'gpurpose_place';
    } elsif ($breadcrumbs =~ /помещение/) {
        $data->{type_code} = 'gpurpose_place';
    }

    # описание
    if ($dom->at('div[class~="item-description-text"]')) {
        $data->{'source_media_text'} = $dom->at('div[class~="item-description-text"]')->all_text;
    }

    # заголовок осн. информация
    my $main_title = $dom->at('h1[class="title-info-title"]')->all_text;
    $main_title = trim $main_title;
    given($data->{'type_code'}) {
        when ('room') {
            my @bp = map {trim $_} grep { $_ && length($_) > 1 } split /[,()]/, $main_title;
            # комната м2 бла...
            if ($bp[0] =~ /^.*?(\d{1,}).*?$/) {
                $data->{'square_total'} = $1;
            }
            # d/d эт.
            if (defined $bp[1] && $bp[1] =~ /^(\d{1,2})\/(\d{1,2}).*?$/) {
                if ($2 >= $1) {
                    $data->{'floor'} = $1;
                    $data->{'floors_count'} = $2;
                }
            }
        }
        when ('apartment') {
            my @bp = map {trim $_} grep { $_ && length($_) > 1 } split /[,()]/, $main_title;
            # d-к квратира.
            if ($bp[0] =~ /^(\d{1,}).*?$/) {
                $data->{'rooms_count'} = $1;
            }
            # d м2.
            if ($bp[1] =~ /^(\d{1,}).*?$/) {
                $data->{'square_total'} = $1;
            }
            # d/d эт.
            if ($bp[2] =~ /^(\d{1,2})\/(\d{1,2}).*?$/) {
                if ($2 >= $1) {
                    $data->{'floor'} = $1;
                    $data->{'floors_count'} = $2;
                }
            }
        }
        when ('house') {
            given($main_title) {
                when (/дом/i) {
                }
                when (/коттедж/i) {
                    $data->{'type_code'} = 'cottage';
                }
                when (/дача/i) {
                    $data->{'type_code'} = 'land';
                }
                # wtf
                default {
                    say 'bla!';
                }
            }

            # d м2 d сот || d м2
            if ($main_title !~ /участке/) {
                if ($main_title =~ /^.*?(\d{1,}).*?$/) {
                    $data->{'square_total'} = $1;
                }
            } elsif ($main_title =~ /^.*?(\d{1,}).*?(\d{1,}).*?$/) {
                $data->{'square_total'} = $1;
                $data->{'square_land'} = $2;
                $data->{'square_land_type'} = 'ar';
            }
        }
        when ('land') {
            if ($main_title =~ /(\d+(?:,\d+)?)\s+кв\.\s*м/) {
                $main_title =~ s/\s//;
                if ($main_title =~ /^(\d{1,}).*?$/) {
                    $data->{'square_land'} = $1;
                }
            } elsif ($main_title =~ s/(\d+)\s+сот\.?//) {
                $data->{'square_land'} = $1;
                $data->{'square_land_type'} = 'ar';
            } elsif ($main_title =~ s/(\d(?:,\d+)?)\s+га//) {
                $data->{'square_land'} = $1 =~ s/,/./r;
                $data->{'square_land_type'} = 'hectare';
            }
        }
        default {}
    }

    #Основная информация
    $dom->find('li[class="item-params-list-item"]')->each (sub {
        my $value = $_->text;
        my $head = lc($_->find('span')->first->text);
        if($head =~ /количество комнат/){
            if($value =~ /студи/){
                $data->{'rooms_count'} = 1;
            } else {
                $data->{'rooms_count'} = trim($value =~ s/-комнат(.)+//r);
            }
        } elsif ($head =~ /этажей в доме/){
            $data->{'floors_count'} = trim($value);
        } elsif ($head =~ /этаж/){
            $data->{'floor'} = trim($value);
        } elsif ($head =~ /общая площадь/){
             $data->{'square_total'} = trim($value =~ s/\sм(.)+//r);
        } elsif ($head =~ /площадь кухни/){
             $data->{'square_kitchen'} = trim($value =~ s/\sм(.)+//r);
        } elsif ($head =~ /жилая площадь/){
             $data->{'square_living'} = trim($value =~ s/\sм(.)+//r);
        } elsif ($head =~ /площадь дома/){
             $data->{'square_total'} = trim($value =~ s/\sм(.)+//r);
        } elsif ($head =~ /площадь участка/){
             $data->{'square_land_type'} = 'ar';
             $data->{'square_land'} = trim($value =~ s/\sсот(.)+//r);
        } elsif ($head =~ /площадь/){
            if($data->{'type_code'} eq 'land'){
                $data->{'square_land_type'} = 'ar';
                $data->{'square_land'} = trim($value =~ s/\sсот(.)+//r);
            } else{
                $data->{'square_total'} = trim($value =~ s/\sм(.)+//r);
            }
        } elsif ($head =~ /(тип дома)|(материал стен)/){
            given ($value) {
                when (/кирпич/) {
                    $data->{house_type_id} = 1;
                }
                when (/панельный/ || /панел/) {
                    $data->{house_type_id} = 3;
                }
                #when (/блочный/ || /газобл/ || /пенобл/) {
                #    return 3;
                #}
                when (/монолитный/) {
                    $data->{house_type_id} = 2;
                }
                when (/деревянный/ || /брус/ || /бревн/) {
                    $data->{house_type_id} = 4;
                }
            }
        }
    });


    # Разделим остальную часть обявления на части и попытаемся вычленить полезную информацию
    if ($data->{'source_media_text'}) {
        my @bp = map {trim $_} grep { $_ && length($_) > 1 } split /[,()]/, $data->{'source_media_text'};
        for my $el (@bp) {
            # Этаж/этажность
            if ($el =~ /^(\d{1,2})\/(\d{1,2})$/) {
                if ($2 > $1) {
                    $data->{'floor'} = $1;
                    $data->{'floors_count'} = $2;
                }
                next;
            }

            for my $k (keys %{$META->{'params'}->{'dict'}}) {
                my %dict = %{$META->{'params'}->{'dict'}->{$k}};
                my $field = delete $dict{'__field__'};
                for my $re (keys %dict) {
                    if ($el =~ /$re/i) {
                        $data->{$field} = $dict{$re};
                        last;
                    }
                }
            }
        }
    }

    # цена в рублях, переведем в тыс.
    if ($dom->at('span[class~="price-value-string"]')) {
        my $price = $dom->at('span[class~="price-value-string"]')->text;
        $price =~s/\s//g;
        if ($price =~ /^(\d{1,}).*?$/) {
            $data->{'owner_price'} = $1 / 1000;
        }
    }

    # адрес
    # нас пункт
    if ($dom->at('meta[itemprop="addressLocality"]')) {
        $data->{locality} = $dom->at('meta[itemprop="addressLocality"]')->attr('content');
    }

    # адр
    if ($dom->find('span[itemprop="streetAddress"]')->first) {
        $data->{address} = $dom->find('span[itemprop="streetAddress"]')->first->all_text;
    }

    my @owner_phones;
    my $item_phone = '';
    my $pkey = '';
    $dom->find('script')->each(sub{
        if ($_->all_text =~ /item.phone = '(.+?)'/) {
            $item_phone = $1;
        }
    });

    $pkey = _phone_demixer($item_id * 1, $item_phone);

    sleep $media_data->{pause};

    my $m_url = 'https://m.avito.ru' . $item_url;

    $ua->get_res($m_url, [
        Host => 'm.avito.ru',
        Referer => $media_data->{site_url},
    ]);

    my $mr = $ua->get_res($m_url . '/phone/' . $pkey . '?async', [
        Host => 'm.avito.ru',
        Referer => $m_url,
        Accept => 'application/json, text/javascript, */*; q=0.01'
    ]);
    if ($mr && $mr->json) {
         my $phone_str = $mr->json->{phone};
        for my $x (split /[.,;:]/, $phone_str) {
            push @owner_phones, $x;
        }
    }
    $data->{'owner_phones'} = \@owner_phones;

    my $seller_name = $dom->find('div[class~="seller-info-prop"]')->first->text;

    if ($seller_name =~ /агентство/i) {
        my $seller = $dom->find('div[class="seller-info-name"] a')->first->text;
        $data->{mediator_company} = $seller;
    } else {
        my $seller_name = $dom->find('div[class="seller-info-col"]')->first->text;
        if ($seller_name =~ /агентство/i) {
            $data->{mediator_company} = $dom->find('div[class="seller-info-col"]')->first->find('a')->first->text;
        }
    }

    # вытащим фото
    my @photos;
    $dom->find('meta[property="og:image"]')->each (sub {
        unless ($_->{content} =~ /logo/) {
            my $img_url = $_->{content};
            push @photos, $img_url;
        }
    });
    $data->{photo_url} = \@photos;

    return $data;
}

sub _phone_demixer {
    my ($id, $key) = @_;

    my @parts = $key =~ /[0-9a-f]+/g;

    my $mixed = join '', $id % 2 == 0 ? reverse @parts : @parts;
    my $s = length $mixed;
    my $r = '';
    my $k;

    for($k = 0; $k < $s; ++ $k) {
        if( $k % 3 == 0 ) {
            $r .= substr $mixed, $k, 1;
        }
    }

    return $r;
}

sub _parse_date {
    my $date = lc(shift);

    my $res;
    my $dt_now = DateTime->now();
    my $year = $dt_now->year();
    my $mon = $dt_now->month();
    my $mday = $dt_now->mday();

    if ($date =~ /сегодня в (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        if ($res > $dt_now) {
            # substr 1 day
            #$res->subtract(days => 1);
        }
    } elsif ($date =~ /вчера в (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        # substr 1 day
        $res->subtract(days => 1);
    } elsif ($date =~ /(\d+) (\w+) в (\d{1,2}):(\d{1,2})/) {
        my $a_mon = _month_num($2);
        my $a_year = $year;
        if ($a_mon > $mon) { $a_year -= 1; }
        $res = $parser->parse_datetime("$a_year-$a_mon-$1 $3:$4");
    } else {
        $res = $dt_now;
    }

    return $res;
}

sub _month_num {
    my $month_str = lc(shift);

    given ($month_str) {
        when (/янв/) {
            return 1;
        }
        when (/фев/) {
            return 2;
        }
        when (/мар/) {
            return 3;
        }
        when (/апр/) {
            return 4;
        }
        when (/мая/) {
            return 5;
        }
        when (/июн/) {
            return 6;
        }
        when (/июл/) {
            return 7;
        }
        when (/авг/) {
            return 8;
        }
        when (/сен/) {
            return 9;
        }
        when (/окт/) {
            return 10;
        }
        when (/ноя/) {
            return 11;
        }
        when (/дек/) {
            return 12;
        }
    }
    return 0;
}

1;
