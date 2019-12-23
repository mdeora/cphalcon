
/**
 * This file is part of the Phalcon Framework.
 *
 * (c) Phalcon Team <team@phalcon.io>
 *
 * For the full copyright and license information, please view the LICENSE.txt
 * file that was distributed with this source code.
 */

namespace Phalcon\Http;

use Phalcon\Di\DiInterface;
use Phalcon\Di\AbstractInjectionAware;
use Phalcon\Crypt\CryptInterface;
use Phalcon\Crypt\Mismatch;
use Phalcon\Filter\FilterInterface;
use Phalcon\Http\Response\Exception;
use Phalcon\Http\Cookie\CookieInterface;
use Phalcon\Http\Cookie\Exception as CookieException;

/**
 * Provide OO wrappers to manage a HTTP cookie.
 */
class Cookie extends AbstractInjectionAware implements CookieInterface
{
    /**
     * @var string
     */
    protected domain;

    /**
     * @var int
     */
    protected expire;

    protected filter;

    /**
     * @var bool
     */
    protected httpOnly;

    /**
     * @var string
     */
    protected name;

    /**
     * @var array
     */
    protected options = [];

    /**
     * @var string
     */
    protected path;

    /**
     * @var bool
     */
    protected read = false;

    /**
     * @var bool
     */
    protected secure;

    /**
     * The cookie's sign key.
     * @var string|null
     */
    protected signKey = null;

    /**
     * @var bool
     */
    protected useEncryption = false;

    /**
     * @var mixed
     */
    protected value;

    /**
     * Phalcon\Http\Cookie constructor.
     */
    public function __construct(
        string! name,
        var value = null,
        int expire = 0,
        string path = "/",
        bool secure = null,
        string domain = null,
        bool httpOnly = false,
        array options = []
    ) {
        let this->name     = name,
            this->expire   = expire,
            this->path     = path,
            this->secure   = secure,
            this->domain   = domain,
            this->httpOnly = httpOnly,
            this->options  = options;

        if value !== null {
            this->setValue(value);
        }
    }

    /**
     * Magic __toString method converts the cookie's value to string
     */
    public function __toString() -> string
    {
        return (string) this->getValue();
    }

    /**
     * Deletes the cookie by setting an expire time in the past
     */
    public function delete()
    {
        var domain, httpOnly, name, options, path, secure;

        let name     = this->name,
            domain   = this->domain,
            path     = this->path,
            secure   = this->secure,
            httpOnly = this->httpOnly,
            options  = this->options;

        let this->value = null;

        setcookie(
            name,
            null,
            time() - 691200,
            path,
            domain,
            secure,
            httpOnly,
            options
        );
    }

    /**
     * Returns the domain that the cookie is available to
     */
    public function getDomain() -> string
    {
        return this->domain;
    }

    /**
     * Returns the current expiration time
     */
    public function getExpiration() -> string
    {
        return this->expire;
    }

    /**
     * Returns if the cookie is accessible only through the HTTP protocol
     */
    public function getHttpOnly() -> bool
    {
        return this->httpOnly;
    }

    /**
     * Returns the current cookie's name
     */
    public function getName() -> string
    {
        return this->name;
    }

    /**
     * Returns the current cookie's options
     */
    public function getOptions() -> array
    {
        return this->options;
    }

    /**
     * Returns the current cookie's path
     */
    public function getPath() -> string
    {
        return this->path;
    }

    /**
     * Returns whether the cookie must only be sent when the connection is
     * secure (HTTPS)
     */
    public function getSecure() -> bool
    {
        return this->secure;
    }

    /**
     * Returns the cookie's value.
     */
    public function getValue(var filters = null, var defaultValue = null) -> var
    {
        var container, value, crypt, decryptedValue, filter, signKey, name;

        let container = null,
            name = this->name;

        if this->read === false {
            if !fetch value, _COOKIE[name] {
                return defaultValue;
            }

            if this->useEncryption {
                let container = <DiInterface> this->container;

                if unlikely typeof container != "object" {
                    throw new Exception(
                        Exception::containerServiceNotFound(
                            "the 'filter' and 'crypt' services"
                        )
                    );
                }

                let crypt = <CryptInterface> container->getShared("crypt");

                if unlikely typeof crypt != "object" {
                    throw new Exception(
                        "A dependency which implements CryptInterface is required to use encryption"
                    );
                }

                /**
                 * Verify the cookie's value if the sign key was set
                 */
                let signKey = this->signKey;

                if typeof signKey === "string" {
                    /**
                     * Decrypt the value also decoding it with base64
                     */
                    let decryptedValue = crypt->decryptBase64(
                        value,
                        signKey
                    );
                } else {
                    /**
                     * Decrypt the value also decoding it with base64
                     */
                    let decryptedValue = crypt->decryptBase64(value);
                }
            } else {
                let decryptedValue = value;
            }

            /**
             * Update the decrypted value
             */
            let this->value = decryptedValue;

            if filters !== null {
                let filter = this->filter;

                if typeof filter != "object" {
                    if container === null {
                        let container = <DiInterface> this->container;

                        if unlikely typeof container != "object" {
                            throw new Exception(
                                Exception::containerServiceNotFound(
                                    "the 'filter' service"
                                )
                            );
                        }
                    }

                    let filter = <FilterInterface> container->getShared("filter"),
                        this->filter = filter;
                }

                return filter->sanitize(decryptedValue, filters);
            }

            /**
             * Return the value without filtering
             */
            return decryptedValue;
        }

        return this->value;
    }

    /**
     * Check if the cookie is using implicit encryption
     */
    public function isUsingEncryption() -> bool
    {
        return this->useEncryption;
    }

    /**
     * Sends the cookie to the HTTP client.
     */
    public function send() -> <CookieInterface>
    {
        var name, value, expire, domain, path, secure, httpOnly, container,
            crypt, encryptValue, signKey;

        let name = this->name,
            value = this->value,
            expire = this->expire,
            domain = this->domain,
            path = this->path,
            secure = this->secure,
            httpOnly = this->httpOnly;

        let container = this->container;

        if this->useEncryption && !empty value {
            if unlikely typeof container != "object" {
                throw new Exception(
                    Exception::containerServiceNotFound(
                        "the 'filter' service"
                    )
                );
            }

            let crypt = <CryptInterface> container->getShared("crypt");

            if unlikely typeof crypt != "object" {
                throw new Exception(
                    "A dependency which implements CryptInterface is required to use encryption"
                );
            }

            /**
             * Encrypt the value also coding it with base64.
             * Sign the cookie's value if the sign key was set
             */
            let signKey = this->signKey;

            if typeof signKey === "string" {
                let encryptValue = crypt->encryptBase64(
                    (string) value,
                    signKey
                );
            } else {
                let encryptValue = crypt->encryptBase64(
                    (string) value
                );
            }
        } else {
            let encryptValue = value;
        }

        /**
         * Sets the cookie using the standard 'setcookie' function
         */
        setcookie(name, encryptValue, expire, path, domain, secure, httpOnly);

        return this;
    }

    /**
     * Sets the domain that the cookie is available to
     */
    public function setDomain(string! domain) -> <CookieInterface>
    {
        let this->domain = domain;

        return this;
    }

    /**
     * Sets the cookie's expiration time
     */
    public function setExpiration(int expire) -> <CookieInterface>
    {
        let this->expire = expire;

        return this;
    }

    /**
     * Sets if the cookie is accessible only through the HTTP protocol
     */
    public function setHttpOnly(bool httpOnly) -> <CookieInterface>
    {
        let this->httpOnly = httpOnly;

        return this;
    }

    /**
     * Sets the cookie's options
     */
    public function setOptions(array! options) -> <CookieInterface>
    {
        let this->options = options;

        return this;
    }

    /**
     * Sets the cookie's path
     */
    public function setPath(string! path) -> <CookieInterface>
    {
        let this->path = path;

        return this;
    }

    /**
     * Sets if the cookie must only be sent when the connection is secure (HTTPS)
     */
    public function setSecure(bool secure) -> <CookieInterface>
    {
        let this->secure = secure;

        return this;
    }

    /**
     * Sets the cookie's sign key.
     *
     * The `$signKey' MUST be at least 32 characters long
     * and generated using a cryptographically secure pseudo random generator.
     *
     * Use NULL to disable cookie signing.
     *
     * @see \Phalcon\Security\Random
     * @throws \Phalcon\Http\Cookie\Exception
     */
    public function setSignKey(string signKey = null) -> <CookieInterface>
    {
        if signKey !== null {
            this->assertSignKeyIsLongEnough(signKey);
        }

        let this->signKey = signKey;

        return this;
    }

    /**
     * Sets the cookie's value
     *
     * @param string value
     */
    public function setValue(value) -> <CookieInterface>
    {
        let this->value = value,
            this->read = true;

        return this;
    }

    /**
     * Sets if the cookie must be encrypted/decrypted automatically
     */
    public function useEncryption(bool useEncryption) -> <CookieInterface>
    {
        let this->useEncryption = useEncryption;

        return this;
    }

    /**
     * Assert the cookie's key is enough long.
     *
     * @throws \Phalcon\Http\Cookie\Exception
     */
    protected function assertSignKeyIsLongEnough(string! signKey) -> void
    {
        var length;

        let length = mb_strlen(signKey);

        if unlikely length < 32 {
            throw new CookieException(
                sprintf(
                    "The cookie's key should be at least 32 characters long. Current length is %d.",
                    length
                )
            );
        }
    }
}
