create index if not exists idx_opt_orders_order_date
    on opt_orders(order_date);

create index if not exists idx_opt_orders_product_id
    on opt_orders(product_id);

create index if not exists idx_opt_orders_client_id
    on opt_orders(client_id);

create index if not exists idx_opt_clients_status
    on opt_clients(status);

---UNOPTIMIZED QUERY:
explain analyze
select
    (
        select concat(product_category, ': ', distinct_clients)
        from (
            select product_category, count(distinct client_id) as distinct_clients
            from (
                select
                    o.order_id,
                    p.product_category,
                    c.id as client_id
                from opt_orders as o
                join opt_products as p
                    on o.product_id = p.product_id
                join opt_clients as c
                    on o.client_id = c.id
                where o.order_date > date '2025-12-01'
                  and c.status = 'active'
            ) as sub1
            group by product_category
        ) as sub2
        where distinct_clients = (
            select min(distinct_clients)
            from (
                select count(distinct client_id) as distinct_clients
                from (
                    select
                        o.order_id,
                        p.product_category,
                        c.id as client_id
                    from opt_orders as o
                    join opt_products as p
                        on o.product_id = p.product_id
                    join opt_clients as c
                        on o.client_id = c.id
                    where o.order_date > date '2025-12-01'
                      and c.status = 'active'
                ) as sub3
                group by product_category
            ) as sub4
        )
        limit 1
    ) as least_diverse_category,

    (
        select concat(product_category, ': ', distinct_clients)
        from (
            select product_category, count(distinct client_id) as distinct_clients
            from (
                select
                    o.order_id,
                    p.product_category,
                    c.id as client_id
                from opt_orders as o
                join opt_products as p
                    on o.product_id = p.product_id
                join opt_clients as c
                    on o.client_id = c.id
                where o.order_date > date '2025-12-01'
                  and c.status = 'active'
            ) as sub1
            group by product_category
        ) as sub2
        where distinct_clients = (
            select max(distinct_clients)
            from (
                select count(distinct client_id) as distinct_clients
                from (
                    select
                        o.order_id,
                        p.product_category,
                        c.id as client_id
                    from opt_orders as o
                    join opt_products as p
                        on o.product_id = p.product_id
                    join opt_clients as c
                        on o.client_id = c.id
                    where o.order_date > date '2025-12-01'
                      and c.status = 'active'
                ) as sub3
                group by product_category
            ) as sub4
        )
        limit 1
    ) as most_diverse_category;
---1720ms

---OPTIMIZED QUERY:
explain analyze
with filtered_orders as (
    select
        o.order_id,
        p.product_category,
        c.id as client_id
    from opt_orders as o
    join opt_products as p
        on o.product_id = p.product_id
    join opt_clients as c
        on o.client_id = c.id
    where o.order_date > date '2025-12-01'
      and c.status = 'active'
),
diversity_by_category as (
    select
        product_category,
        count(distinct client_id) as distinct_clients
    from filtered_orders
    group by product_category
),
ranked_categories as (
    select
        product_category,
        distinct_clients,
        row_number() over (order by distinct_clients asc, product_category asc) as min_rn,
        row_number() over (order by distinct_clients desc, product_category asc) as max_rn
    from diversity_by_category
)
select
    max(concat(product_category, ': ', distinct_clients)) filter (where min_rn = 1) as least_diverse_category,
    max(concat(product_category, ': ', distinct_clients)) filter (where max_rn = 1) as most_diverse_category
from ranked_categories;
---296ms


---test
DROP INDEX IF EXISTS idx_opt_orders_order_date;
DROP INDEX IF EXISTS idx_opt_orders_product_id;
DROP INDEX IF EXISTS idx_opt_orders_client_id;
DROP INDEX IF EXISTS idx_opt_clients_status;
